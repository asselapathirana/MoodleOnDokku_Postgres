#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH=/var/www/html/config.php
PERSIST_PATH=/var/www/moodledata/config.php

mkdir -p /var/www/moodledata
chown -R www-data:www-data /var/www/moodledata

# Dokku rejects env keys with dashes, so accept PHP_INI_* and translate to ini
PHP_INI_ENV_FILE=/usr/local/etc/php/conf.d/zz-env.ini
if env | grep -q '^PHP_INI_'; then
  : > "$PHP_INI_ENV_FILE"
  while IFS='=' read -r key value; do
    case "$key" in
      PHP_INI_*)
        ini_key="${key#PHP_INI_}"
        ini_key="${ini_key,,}"
        printf '%s=%s\n' "$ini_key" "$value" >> "$PHP_INI_ENV_FILE"
        ;;
    esac
  done < <(env)
fi

# Parse PG_URL into discrete vars if provided
if [ -n "${PG_URL:-}" ]; then
  eval "$(
    php -r '
      $url = getenv("PG_URL");
      $parts = parse_url($url);
      if ($parts === false) {
        fwrite(STDERR, "Invalid PG_URL\n");
        exit(1);
      }
      $host = $parts["host"] ?? "";
      $port = $parts["port"] ?? 5432;
      $user = $parts["user"] ?? "";
      $pass = $parts["pass"] ?? "";
      $db = ltrim($parts["path"] ?? "", "/");
      parse_str($parts["query"] ?? "", $query);
      $sslmode = $query["sslmode"] ?? "";
      $pairs = [
        "MOODLE_DB_HOST" => $host,
        "MOODLE_DB_PORT" => $port,
        "MOODLE_DB_USER" => $user,
        "MOODLE_DB_PASS" => $pass,
        "MOODLE_DB_NAME" => $db,
      ];
      foreach ($pairs as $k => $v) {
        printf("%s=%s\n", $k, escapeshellarg($v));
      }
      if ($sslmode !== "") {
        printf("MOODLE_DB_SSLMODE=%s\n", escapeshellarg($sslmode));
      }
    '
  )"
  export MOODLE_DB_HOST MOODLE_DB_PORT MOODLE_DB_USER MOODLE_DB_PASS MOODLE_DB_NAME MOODLE_DB_SSLMODE
fi

# Restore persisted config if present
if [ -f "$PERSIST_PATH" ] && [ ! -f "$CONFIG_PATH" ]; then
  cp "$PERSIST_PATH" "$CONFIG_PATH"
  chown www-data:www-data "$CONFIG_PATH"
fi

# Optionally generate config.php from environment
if [ "${MOODLE_CONFIG_FROM_ENV:-}" = "1" ] && [ ! -f "$CONFIG_PATH" ]; then
  : "${WWWROOT:?WWWROOT is required}"
  : "${MOODLE_DB_HOST:?MOODLE_DB_HOST is required}"
  : "${MOODLE_DB_NAME:?MOODLE_DB_NAME is required}"
  : "${MOODLE_DB_USER:?MOODLE_DB_USER is required}"
  : "${MOODLE_DB_PASS:?MOODLE_DB_PASS is required}"

  cat > "$CONFIG_PATH" <<'PHP'
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost = getenv('MOODLE_DB_HOST');
$CFG->dbname = getenv('MOODLE_DB_NAME');
$CFG->dbuser = getenv('MOODLE_DB_USER');
$CFG->dbpass = getenv('MOODLE_DB_PASS');
$CFG->prefix = getenv('MOODLE_DB_PREFIX') ?: 'mdl_';
$CFG->dboptions = array(
  'dbpersist' => 0,
  'dbport' => getenv('MOODLE_DB_PORT') ?: 5432,
  'sslmode' => getenv('MOODLE_DB_SSLMODE') ?: '',
  'dbsocket' => '',
  'dbcollation' => 'utf8',
);

$CFG->wwwroot = getenv('WWWROOT');
$CFG->dataroot = getenv('MOODLE_DATA_DIR') ?: '/var/www/moodledata';
$CFG->admin = 'admin';

$CFG->directorypermissions = 02770;

require_once(__DIR__ . '/lib/setup.php');
PHP

  chown www-data:www-data "$CONFIG_PATH"
fi

# Persist config for future restarts
if [ -f "$CONFIG_PATH" ] && [ ! -f "$PERSIST_PATH" ]; then
  cp "$CONFIG_PATH" "$PERSIST_PATH"
  chown www-data:www-data "$PERSIST_PATH"
fi
