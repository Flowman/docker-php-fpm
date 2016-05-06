FROM alpine:latest

MAINTAINER Peter Szalatnay <theotherland@gmail.com>

ENV PHP_VERSION=7.0.6 PHP_FILENAME=php-7.0.6.tar.xz NEWRELIC_FILENAME=newrelic-php5-6.2.1.0-linux-musl.tar.gz

RUN \
    addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk add --update \
        curl \
        libxml2 \
        readline \
        freetype \
        libjpeg-turbo \
        libpng \
        libwebp \
        libedit \
        libzip@testing \
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
        openssl-dev \
        sqlite-dev \
        readline-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libmcrypt-dev \
        libedit-dev \
    && curl -fSL "http://php.net/get/$PHP_FILENAME/from/this/mirror" -o "$PHP_FILENAME" \
    && mkdir -p /usr/src \
    && tar -Jxf "$PHP_FILENAME" -C /usr/src \
    && mv "/usr/src/php-$PHP_VERSION" /tmp/php \
    && rm "$PHP_FILENAME" \
    && cd /tmp/php \
    && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/php \
        --with-config-file-path=/etc/php \
        --with-config-file-scan-dir=/etc/php/conf.d \
        --enable-fpm --with-fpm-user=nginx --with-fpm-group=nginx \
        --disable-rpath \
        --disable-static \
        --disable-debug \
        --disable-cgi \
        --enable-mysqlnd \
        --enable-mbstring \
        --enable-opcache \
        --enable-zip \
        --enable-libxml --with-libxml-dir=/usr \
        --with-libdir=/lib/x86_64-linux-gnu \
        --with-freetype-dir=/usr \
        --with-zlib --with-zlib-dir=/usr \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        --with-mysqli \
        --with-gd --with-jpeg-dir=/usr --with-webp-dir=/usr --with-png-dir=/usr \
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

    # install xdebug (but it will be disabled, see /etc/php/conf.d/xdebug.ini)
    && cd /tmp \
    && git clone https://github.com/xdebug/xdebug.git \
    && cd xdebug \
    && git checkout master \
    && phpize && ./configure --enable-xdebug && make \
    && cp modules/xdebug.so /usr/lib/php/extensions/no-debug-non-zts-20151012 \
    && echo "zend_extension=xdebug.so" >> "/etc/php/conf.d/docker-php-ext-xdebug.ini" \

    # install newrelic apm agent
    && apk add --update --no-cache tar \
    && curl -fSL "https://download.newrelic.com/php_agent/release/$NEWRELIC_FILENAME" -o "newrelic.tar.gz" \
    && mkdir -p /tmp/newrelic /var/log/newrelic \
    && tar --strip-components=1 -xzf "newrelic.tar.gz" -C /tmp/newrelic \
    && rm "newrelic.tar.gz" \
    && cd /tmp/newrelic \
    && cp agent/x64/newrelic-20151012.so /usr/lib/php/extensions/no-debug-non-zts-20151012/newrelic.so \
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
