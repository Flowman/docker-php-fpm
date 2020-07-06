# What is PHP-FPM?

PHP-FPM (FastCGI Process Manager) is an alternative PHP FastCGI implementation with some additional features useful for sites of any size, especially busier sites.

## Info

The container is optimized to run !Joomla with Nginx, so some PHP modules have been striped out. Check the build section to customize this container for your needs.

This image is based on the popular Alpine Linux project, available in the alpine official image. Alpine Linux is much smaller than most distribution base images (~5MB), and thus leads to much slimmer images in general.

## Usage

```bash
docker run -d flowman/php-fpm:tag
```

To enable New Relic APM

```bash
docker run -d \
           -e NEWRELIC_KEY=xxxxxx \
           -e NEWRELIC_APP_NAME="Awesome PHP App" \
           flowman/php-fpm:tag
```

### Environment Variables

`NEWRELIC_KEY`

This variable is optional and will enable [New Relic APM](https://newrelic.com/application-monitoring) to monitor your php application. Enter your New Relic license key.

This will disable xdebug as APM is not compatible with it.

`NEWRELIC_APP_NAME`

This variable is optional and is used to set the application name for APM.

`XDEBUG`

This variable is optional and will enable xdebug.

## ... via `docker-compose`

Example docker-compose file

```yaml
version: '2'
services:
  nginx:
    image: flowman/nginx:1.18.0
    ports:
     - "80:80"
    volumes_from:
      - 'joomla'
  php-fpm:
    image: flowman/php-fpm:7.4.7
    network_mode: "service:nginx"
    volumes_from:
      - 'joomla'
    environment:
      XDEBUG: 'true'
  joomla:
    image: flowman/joomla:3.9.18
    network_mode: none
```

## Build

For example, if you need to install or remove php extensions, edit the Dockerfile and than build-it.

```bash
git clone git@github.com:Flowman/docker-php-fpm.git
cd ./docker-php-fpm
docker build --rm -t flowman/php-fpm .
```
