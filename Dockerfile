FROM php:7.4.16-fpm-alpine3.13

LABEL maintainer="Peter Szalatnay <theotherland@gmail.com>"

ENV NEWRELIC_FILENAME=newrelic-php5-9.16.0.295-linux-musl.tar.gz
ENV XDEBUG_VERSION=3.0.3

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
        zlib-dev \
        libpng-dev \
        libwebp-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libzip-dev \
        $PHPIZE_DEPS; \
    pecl install xdebug-$XDEBUG_VERSION; \
    docker-php-ext-configure zip; \
    docker-php-ext-configure gd \
    --with-webp=/usr/include/ \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/; \
    docker-php-ext-install opcache gd mysqli zip; \
    apk del .build-deps; \
    # install newrelic apm agent
    cd /tmp; \
    curl -fSL "https://download.newrelic.com/php_agent/release/$NEWRELIC_FILENAME" -o "$NEWRELIC_FILENAME"; \
    mkdir -p /tmp/newrelic /var/log/newrelic; \
    tar -xzf "$NEWRELIC_FILENAME" -C /tmp/newrelic --strip-components=1; \
    rm "$NEWRELIC_FILENAME"; \
    cd /tmp/newrelic; \
    cp agent/x64/newrelic-20190902.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/newrelic.so; \
    cp daemon/newrelic-daemon.x64 /usr/bin/newrelic-daemon; \
    cp scripts/newrelic.ini.template /usr/local/etc/php/conf.d/newrelic.ini; \
    sed -i -e 's/^extension = "newrelic.so"/;extension = "newrelic.so"/g' /usr/local/etc/php/conf.d/newrelic.ini; \
    rm -rf /tmp/*;

COPY dockerdir /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]
