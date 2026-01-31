FROM moodlehq/moodle-php-apache:8.3

ARG MOODLE_VERSION=5.1.1
ARG MOODLE_SHA256=

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Add our entrypoint hooks (run by the base image on container start)
COPY docker-entrypoint.d/ /docker-entrypoint.d/
COPY docker-entrypoint.sh /usr/local/bin/moodle-entrypoint

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL -o /tmp/moodle.tgz \
      "https://download.moodle.org/download.php/direct/stable501/moodle-${MOODLE_VERSION}.tgz"; \
    if [ -n "${MOODLE_SHA256}" ]; then \
      echo "${MOODLE_SHA256}  /tmp/moodle.tgz" | sha256sum -c -; \
    fi; \
    tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1; \
    rm -f /tmp/moodle.tgz; \
    chown -R www-data:www-data /var/www/html; \
    chmod +x /usr/local/bin/moodle-entrypoint

ENTRYPOINT [\"/usr/local/bin/moodle-entrypoint\"]
CMD [\"apache2-foreground\"]
