FROM php:7.4.20-fpm-alpine3.13

LABEL maintainer="Peter Szalatnay <theotherland@gmail.com>"

ENV XDEBUG_VERSION=3.0.4
ENV DATADOG_FILENAME=datadog-php-tracer_0.60.0_noarch.apk

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
        libzip \
        libgomp \
        imagemagick; \
    apk add --no-cache --virtual .build-deps \
        zlib-dev \
        libpng-dev \
        libwebp-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libzip-dev \
        imagemagick-dev \
        $PHPIZE_DEPS; \
    pecl install xdebug-$XDEBUG_VERSION; \
    docker-php-ext-configure zip; \
    docker-php-ext-configure gd \
    --with-webp=/usr/include/ \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/; \
    docker-php-ext-install opcache gd mysqli zip; \
    pecl install imagick; \
    docker-php-ext-enable imagick; \
    apk del .build-deps; \
    cd /tmp; \
    curl -fSL "https://github.com/DataDog/dd-trace-php/releases/latest/download/$DATADOG_FILENAME" -o "$DATADOG_FILENAME"; \
    apk add $DATADOG_FILENAME --allow-untrusted; \
    sed -i -e 's/^extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/;extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/g' /usr/local/etc/php/conf.d/98-ddtrace.ini; \
    rm -rf /tmp/*;

COPY dockerdir /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]
