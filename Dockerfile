FROM php:8.3.11-fpm-alpine3.20

ARG PHP_EXTS="intl gd mysqli zip opcache"
ARG XDEBUG_VERSION=3.3.2

LABEL author="Peter Szalatnay <https://github.com/flowman>" \
      description="PHP-FPM optimized for !Joomla"

RUN set -eux; \
    addgroup -g 101 -S nginx; \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx; \
    \
    # Install basic packages    
    apk add --no-cache \
        git \
        ghostscript \
        imagemagick \
        icu-libs \
        libzip \
    ; \
    \
    # Install temporary build dependencies        
    apk add --no-cache --virtual .build-deps \
        ${PHPIZE_DEPS} \
        freetype-dev \
        icu-dev \
        imagemagick-dev \        
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        linux-headers \
    ; \
    apk add --no-cache --virtual \
        .docker-php-ext-enable-deps \
    ; \
    \
    # Install XDEBUG extension
    pecl install xdebug-${XDEBUG_VERSION}; \
    docker-php-ext-enable xdebug; \
    \
    # Configure PHP extensions
    docker-php-ext-configure zip; \
    docker-php-ext-configure intl; \
    docker-php-ext-configure gd \
        --with-webp=/usr/include/ \
        --with-freetype=/usr/include/ \
        --with-jpeg=/usr/include/; \
    \
    # Install PHP extensions
    docker-php-ext-install ${PHP_EXTS}; \
    pecl install imagick; \
    docker-php-ext-enable imagick; \
    \
    # Cleanup:
    # - remove build dependencies
    apk del --no-network .build-deps; \
    rm -rf /tmp/*;

COPY dockerdir /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["php-fpm"]
