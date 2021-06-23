#!/bin/sh

set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ]; then
    if [ ! -z "$XDEBUG" ]; then
        docker-php-ext-enable xdebug

        sed -i -e 's/^zend_extension=opcache.so/;zend_extension=opcache.so/g' /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
        sed -i -e 's/^extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/;extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/g' /usr/local/etc/php/conf.d/98-ddtrace.ini
    fi

    if [ ! -z "$DATADOG" ]; then
        sed -i -e 's/^;extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/extension=\/opt\/datadog-php\/extensions\/ddtrace-20190902-alpine.so/g' /usr/local/etc/php/conf.d/98-ddtrace.ini
    fi
fi

exec "$@"
