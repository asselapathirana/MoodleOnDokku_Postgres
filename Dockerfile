FROM moodlehq/moodle-php-apache:8.3

ARG MOODLE_VERSION=5.1.1
ARG MOODLE_SHA256=9b79fba5518ea5b9d35b7163d043ca189ae3f1c647e0152143be755292b73964

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Add our entrypoint hooks (run by the base image on container start)
COPY docker-entrypoint.d/ /docker-entrypoint.d/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL -o /tmp/moodle.tgz \
      "https://download.moodle.org/download.php/stable501/moodle-${MOODLE_VERSION}.tgz"; \
    echo "${MOODLE_SHA256}  /tmp/moodle.tgz" | sha256sum -c -; \
    tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1; \
    rm -f /tmp/moodle.tgz; \
    chown -R www-data:www-data /var/www/html
