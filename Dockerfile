FROM php:7.4.1-apache-buster as base

ENV APACHE_DOCUMENT_ROOT=/var/www/project/public
ENV APACHE_RUN_USER=dockeruser
ENV APACHE_RUN_GROUP=dockergroup

RUN addgroup dockergroup --gid 1000
RUN adduser --ingroup dockergroup --uid 1000 dockeruser --gecos "" --disabled-password

RUN apt-get update
RUN apt-get install -y libicu-dev vim libonig-dev zip unzip libzip-dev

RUN docker-php-ext-install bcmath opcache intl

RUN mkdir -p /var/run/apache2 /var/www/project && \
    chown -R dockeruser:dockergroup /usr/sbin/apache2 /var/run/apache2 /var/www/project /var/log/apache2 && \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
    ln -sf /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load && \
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log && \
    cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini && \
    # allow $_ENV to be defined throught apache
    sed -ri -e 's!variables_order = "GPCS"!variables_order = "EGPCS"!' /usr/local/etc/php/php.ini

COPY ./docker-secret-entrypoint /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-secret-entrypoint
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# -------------------- DEVELOPMENT  ------------------------ #

FROM base as development

USER root

RUN rm -rf /var/lib/apt/lists/* && \
        apt-get update

RUN apt-get install -y git zlib1g-dev libmemcached-dev librabbitmq-dev default-libmysqlclient-dev libpq-dev

# use 8000 in dev environment because user is not root.and we cannot launch apache in port 80 without root.
RUN sed -ri -e 's!80!8000!g' /etc/apache2/ports.conf /etc/apache2/sites-available/*.conf

RUN docker-php-ext-install pdo zip pdo_mysql pdo_pgsql
RUN pecl install redis xdebug memcached amqp
RUN docker-php-ext-enable amqp redis xdebug

USER dockeruser

EXPOSE 8000
