FROM php:8.4-fpm-alpine
RUN docker-php-ext-install pdo_mysql
RUN printf "expose_php=Off\ndisplay_errors=Off\nlog_errors=On\n" > /usr/local/etc/php/conf.d/seguridad.ini
COPY . /var/www/backend
RUN mkdir -p /var/www/backend/storage && chown -R www-data:www-data /var/www/backend/storage