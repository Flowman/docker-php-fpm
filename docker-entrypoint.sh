#!/bin/sh

set -e

# if command starts with an option, prepend dovecot
if [ "${1:0:1}" = '-' ]; then
    set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ]; then

    if [ ! -z "$NEWRELIC_KEY" ]; then

        sed -i -e 's/;extension = "newrelic.so"/extension = "newrelic.so"/g' /etc/php/conf.d/newrelic.ini
        sed -i -e 's/zend_extension=xdebug.so/;zend_extension=xdebug.so/g' /etc/php/conf.d/docker-php-ext-xdebug.ini

        if [ "$NEWRELIC_KEY" ]; then
            sed -i -e "s/REPLACE_WITH_REAL_KEY/$NEWRELIC_KEY/g" /etc/php/conf.d/newrelic.ini
        fi

        if [ "$NEWRELIC_APP_NAME" ]; then
            sed -i -e "s/PHP Application/$NEWRELIC_APP_NAME/g" /etc/php/conf.d/newrelic.ini
        fi
    fi

    if [ ! -z "$XDEBUG" ]; then
        sed -i -e 's/xdebug.default_enable = 0/xdebug.default_enable = 1/g' /etc/php/conf.d/xdebug.ini
    fi

fi

exec "$@"
