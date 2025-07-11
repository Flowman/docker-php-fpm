#!/bin/sh

set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ]; then
    if [ ! -z "$XDEBUG" ]; then
        sed -i -e 's/^;zend_extension=xdebug/zend_extension=xdebug/g' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
        sed -i -e 's/^zend_extension=opcache/;zend_extension=opcache/g' /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
    else
        sed -i -e 's/^zend_extension=xdebug/;zend_extension=xdebug/g' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
        sed -i -e 's/^;zend_extension=opcache/zend_extension=opcache/g' /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
    fi
fi

exec "$@"