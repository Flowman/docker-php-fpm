FROM alpine:3.13.2

LABEL maintainer="Peter Szalatnay <theotherland@gmail.com>"

ENV PHP_VERSION=7.4.16
ENV PHP_FILENAME=php-7.4.16.tar.xz
ENV NEWRELIC_FILENAME=newrelic-php5-9.16.0.295-linux-musl.tar.gz

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -pie"

RUN set -eux; \
    addgroup -S nginx; \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
    apk add --update --no-cache \
        curl \
        git \
        openssh-client \
        tar \
        xz \
        libxml2 \
        readline \
        freetype \
        libjpeg-turbo \
        libpng \
        libwebp \
        libedit \
        libmcrypt \
        libbz2 \
        libzip; \
    apk add --no-cache --virtual .build-deps \
        git \
        autoconf \
        file \
        g++ \
        gcc \
        libc-dev \
        make \
        pkgconf \
        re2c \
        curl-dev \
        libedit-dev \
        libxml2-dev \
        readline-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libmcrypt-dev \
        libedit-dev \
        libssh2-dev \
        libzip-dev \
        oniguruma-dev; \
    # download sources
    cd /tmp; \
    curl -fSL "http://php.net/get/$PHP_FILENAME/from/this/mirror" -o "$PHP_FILENAME"; \
    mkdir -p /tmp/php; \
    tar -Jxf "$PHP_FILENAME" -C /tmp/php --strip-components=1; \
    rm "$PHP_FILENAME"; \
    cd /tmp/php; \
    export CFLAGS="$PHP_CFLAGS" \
        CPPFLAGS="$PHP_CPPFLAGS" \
        LDFLAGS="$PHP_LDFLAGS"; \
    ./configure \
        --prefix=/usr \
        --libdir=/usr/lib/php \
        --datadir=/usr/share/php \
        --sysconfdir=/etc/php \
        --localstatedir=/etc/php/var \
        --with-pear=/usr/share/php \
        --with-config-file-scan-dir=/etc/php/conf.d \
        --with-config-file-path=/etc/php \
        --disable-debug \
        --disable-cgi \
        --disable-gd-jis-conv \
        --disable-short-tags \
        --enable-fpm --with-fpm-user=nginx --with-fpm-group=nginx \
        --enable-mysqlnd \
        --enable-mbstring \
        --enable-opcache \
        --with-zip \
        --with-libxml \
        --enable-sockets \
        --with-mysqli \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --enable-gd \
        --with-jpeg \
        --with-webp \
        --with-freetype \
        --with-zlib \
        --without-readline \
        --without-sqlite3 \
        --without-pdo-sqlite; \
    make; \
    make install; \
    { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }; \
    make clean; \
    runDeps="$( \
        scanelf --needed --nobanner --recursive /usr/local \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )"; \
    apk add --virtual .php-rundeps $runDeps; \
    mkdir /etc/php/conf.d/; \
    echo "zend_extension=opcache.so" >> "/etc/php/conf.d/docker-php-ext-opcache.ini"; \
    # install xdebug (but it will be disabled, see /etc/php/conf.d/xdebug.ini)
    cd /tmp; \
    git clone https://github.com/xdebug/xdebug.git; \
    cd /tmp/xdebug; \
    git checkout master; \
    phpize ./configure --enable-xdebug make install; \
    echo ";zend_extension=xdebug.so" >> "/etc/php/conf.d/docker-php-ext-xdebug.ini"; \
    # install newrelic apm agent
    cd /tmp; \
    curl -fSL "https://download.newrelic.com/php_agent/release/$NEWRELIC_FILENAME" -o "$NEWRELIC_FILENAME"; \
    mkdir -p /tmp/newrelic /var/log/newrelic; \
    tar -xzf "$NEWRELIC_FILENAME" -C /tmp/newrelic --strip-components=1; \
    rm "$NEWRELIC_FILENAME"; \
    cd /tmp/newrelic; \
    cp agent/x64/newrelic-20190902.so /usr/lib/php/extensions/no-debug-non-zts-20190902/newrelic.so; \
    cp daemon/newrelic-daemon.x64 /usr/bin/newrelic-daemon; \
    cp scripts/newrelic.ini.template /etc/php/conf.d/newrelic.ini; \
    # remove PHP dev dependencies
    apk del .build-deps; \
    rm -rf /tmp/*; \
    cd /etc/php; \
    if [ -d php-fpm.d ]; then \
        # for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
        sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
    fi; \
    { \
        echo '[global]'; \
        echo 'error_log = /proc/self/fd/2'; \
        echo 'daemonize = no'; \
        echo; \
        echo '[www]'; \
        echo '; if we send this to /proc/self/fd/1, it never appears'; \
        echo ';access.log = /proc/self/fd/2'; \
        echo; \
        echo 'clear_env = no'; \
        echo; \
        echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
        echo 'catch_workers_output = yes'; \
    } | tee php-fpm.d/docker.conf

COPY dockerdir /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000

CMD ["php-fpm"]
