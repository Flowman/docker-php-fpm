FROM alpine:3.9

MAINTAINER Peter Szalatnay <theotherland@gmail.com>

ENV PHP_VERSION=7.3.2 PHPREDIS_FILENAME=4.2.0.tar.gz PHP_FILENAME=php-7.3.2.tar.xz NEWRELIC_FILENAME=newrelic-php5-8.5.0.235-linux-musl.tar.gz

RUN \
    addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --update \
        curl \
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
        libzip \
    && apk add --no-cache --virtual .build-deps \
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
    # download sources
    && cd /tmp \
    && curl -fSL "http://php.net/get/$PHP_FILENAME/from/this/mirror" -o "$PHP_FILENAME" \
    && mkdir -p /tmp/php \
    && tar -Jxf "$PHP_FILENAME" -C /tmp/php --strip-components=1 \
    && rm "$PHP_FILENAME" \
    && cd /tmp/php \
    && ./configure \
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
        --enable-zip \
        --enable-libxml --with-libxml-dir \
        --with-mysqli \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --with-gd \
        --with-jpeg-dir \
        --with-png-dir \
        --with-webp-dir \
        --with-xpm-dir=no \
        --with-freetype-dir \
        --with-zlib \
        --without-readline \
        --without-sqlite3 \
        --without-pdo-sqlite \
    && make \
    && make install \
    && { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && make clean \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive /usr/local \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --virtual .php-rundeps $runDeps \
    && mkdir /etc/php/conf.d/ \
    && echo "zend_extension=opcache.so" >> "/etc/php/conf.d/docker-php-ext-opcache.ini" \
    # install phpredis
    && cd /tmp \
    && curl -fSL "https://github.com/phpredis/phpredis/archive/$PHPREDIS_FILENAME" -o "$PHPREDIS_FILENAME" \
    && mkdir -p /tmp/phpredis \
    && tar -xzf "$PHPREDIS_FILENAME" -C /tmp/phpredis --strip-components=1 \
    && cd /tmp/phpredis \
    && phpize && ./configure && make install \
    && echo "extension=redis.so" >> "/etc/php/conf.d/docker-php-ext-redis.ini" \
    # install xdebug (but it will be disabled, see /etc/php/conf.d/xdebug.ini)
    && cd /tmp \
    && git clone https://github.com/xdebug/xdebug.git \
    && cd /tmp/xdebug \
    && git checkout master \
    && phpize && ./configure --enable-xdebug && make install \
    && echo ";zend_extension=xdebug.so" >> "/etc/php/conf.d/docker-php-ext-xdebug.ini" \
    # install newrelic apm agent
    && cd /tmp \
    && curl -fSL "https://download.newrelic.com/php_agent/release/$NEWRELIC_FILENAME" -o "$NEWRELIC_FILENAME" \
    && mkdir -p /tmp/newrelic /var/log/newrelic \
    && tar -xzf "$NEWRELIC_FILENAME" -C /tmp/newrelic --strip-components=1 \
    && rm "$NEWRELIC_FILENAME" \
    && cd /tmp/newrelic \
    && cp agent/x64/newrelic-20180731.so /usr/lib/php/extensions/no-debug-non-zts-20180731/newrelic.so \
    && cp daemon/newrelic-daemon.x64 /usr/bin/newrelic-daemon \
    && cp scripts/newrelic.ini.template /etc/php/conf.d/newrelic.ini \
    # remove PHP dev dependencies
    && apk del .build-deps \
    && rm -rf /tmp/* \
    && cd /etc/php \
    && if [ -d php-fpm.d ]; then \
        # for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
        sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
    fi \
    && { \
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

COPY ./www.conf /etc/php/php-fpm.d/www.conf
COPY ./opcache.ini ./xdebug.ini /etc/php/conf.d/
COPY ./docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9000

CMD ["php-fpm"]
