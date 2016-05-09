[![](https://badge.imagelayers.io/flowman/php-fpm:latest.svg)](https://imagelayers.io/?images=flowman/php-fpm:latest 'Get your own badge on imagelayers.io')

# What is PHP-FPM?

PHP-FPM (FastCGI Process Manager) is an alternative PHP FastCGI implementation with some additional features useful for sites of any size, especially busier sites.

## Info

This container is not meant to be run standalone as it is part of a [Rancher](http://rancher.com) Catalog item. If it suites your purpose you are more then welcome to use it.

The container is optimized to run !Joomla with Nginx, so some PHP modules have been striped out. Check the build section to customize this container for your needs.

This image is based on the popular Alpine Linux project, available in the alpine official image. Alpine Linux is much smaller than most distribution base images (~5MB), and thus leads to much slimmer images in general.

## Usage

```
$ docker run -d flowman/php-fpm:tag
```

To enable New Relic APM

```
$ docker run -d -e NEWRELIC_KEY=xxxxxx -e NEWRELIC_APP_NAME="Awesome PHP App" flowman/php-fpm:tag
```

### Environment Variables

```
NEWRELIC_KEY
```

This variable is optional and will enable [New Relic APM](https://newrelic.com/application-monitoring) to monitor your php application. Enter your New Relic license key.

This will disable xdebug as APM is not compatible with it.

```
NEWRELIC_APP_NAME
```

This variable is optional and is used to set the application name for APM.

```
XDEBUG
```

This variable is optional and will enable xdebug.

## ... via `docker-compose`

Example Rancher docker-compose stack

```
nginx:
  image: flowman/nginx:1.10.0
  labels:
    io.rancher.sidekicks: php-fpm, www-data
  volumes_from:
    - 'www-data'
  ports:
   - "80:80"
php-fpm:
  image: flowman/php-fpm:7.0.6
  net: "container:nginx"
  volumes_from:
    - 'www-data'
  environment:
    XDEBUG: 'true'
www-data:
  image: flowman/joomla:3.5.1
  net: none
  command: /bin/true
  labels:
    io.rancher.container.start_once: true
```

Example docker-compose file

```
version: '2'
services:
  nginx:
    image: flowman/nginx:1.10.0
    ports:
     - "80:80"
    volumes_from:
      - 'joomla'
  php-fpm:
    image: flowman/php-fpm:7.0.6
    network_mode: "service:nginx"
    volumes_from:
      - 'joomla'
    environment:
      XDEBUG: 'true'
  joomla:
    image: flowman/joomla:3.5.1
    network_mode: none
```

## Build

For example, if you need to install or remove php extensions, edit the Dockerfile and than build-it.

```
git clone git@github.com:Flowman/docker-php-fpm.git
cd ./docker-php-fpm
docker build --rm -t flowman/php-fpm .
```
