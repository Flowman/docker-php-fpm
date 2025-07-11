FROM php:8.3.23-fpm-alpine3.22

LABEL author="Peter Szalatnay <https://github.com/flowman>" \
      description="PHP-FPM optimized for !Joomla"

ARG PHP_EXTS="intl gd mysqli zip opcache bcmath"
ARG XDEBUG_VERSION=3.4.4

ENV XDEBUG_PORT=9003
ENV XDEBUG_HOST=host.k3d.internal

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
    #pecl install imagick; \
# WARNING: imagick is likely not supported on Alpine: https://github.com/Imagick/imagick/issues/328
# https://pecl.php.net/package/imagick
# https://github.com/Imagick/imagick/commit/5ae2ecf20a1157073bad0170106ad0cf74e01cb6 (causes a lot of build failures, but strangely only intermittent ones)
# see also https://github.com/Imagick/imagick/pull/641
# this is "pecl install imagick-3.7.0", but by hand so we can apply a small hack / part of the above commit
# Thanks to @tianon https://github.com/docker-library/wordpress/commit/509adb58cbc7463a03e317931df65868ec8a3e92
    curl -fL -o imagick.tgz 'https://pecl.php.net/get/imagick-3.7.0.tgz'; \
    echo '5a364354109029d224bcbb2e82e15b248be9b641227f45e63425c06531792d3e *imagick.tgz' | sha256sum -c -; \
    tar --extract --directory /tmp --file imagick.tgz imagick-3.7.0; \
    grep '^//#endif$' /tmp/imagick-3.7.0/Imagick.stub.php; \
    test "$(grep -c '^//#endif$' /tmp/imagick-3.7.0/Imagick.stub.php)" = '1'; \
    sed -i -e 's!^//#endif$!#endif!' /tmp/imagick-3.7.0/Imagick.stub.php; \
    grep '^//#endif$' /tmp/imagick-3.7.0/Imagick.stub.php && exit 1 || :; \
    docker-php-ext-install /tmp/imagick-3.7.0; \
    rm -rf imagick.tgz /tmp/imagick-3.7.0; \
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
