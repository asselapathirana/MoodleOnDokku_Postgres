# Moodle 5.1.x on Dokku (vanilla)

This repo builds a Moodle 5.1.x image from the official `moodlehq/moodle-php-apache` base, and wires runtime config from env vars.

## Prereqs
- Dokku host: `srv.wg`
- Domain: `lms.srv.pathirana.net` (TLS handled by Traefik)
- External Postgres reachable over WireGuard

## Build + deploy

```bash
# On your local machine
cd /mnt/e/learn/webapps_ALL/moodle

git init
# add your remote (adjust if using a different user)
git remote add dokku dokku@srv.wg:moodle

# First push
# If your default branch is main, push main
# If your default branch is master, push master
# Use whichever applies:
# git push dokku main
# git push dokku master
```

```bash
# On the Dokku host

dokku apps:create moodle

dokku domains:set moodle lms.srv.pathirana.net

# Persist moodledata
mkdir -p /var/lib/dokku/data/storage/moodle/moodledata
chown -R dokku:dokku /var/lib/dokku/data/storage/moodle

dokku storage:mount moodle \
  /var/lib/dokku/data/storage/moodle/moodledata:/var/www/moodledata

# Runtime config
# PG_URL example: postgresql://user:pass@host:port/dbname?sslmode=require

dokku config:set moodle \
  MOODLE_CONFIG_FROM_ENV=1 \
  WWWROOT=https://lms.srv.pathirana.net \
  MOODLE_REVERSEPROXY=1 \
  MOODLE_SSLPROXY=1 \
  MOODLE_DB_HOST=10.50.0.1 \
  MOODLE_DB_PORT=5435 \
  MOODLE_DB_NAME=moodle_db \
  MOODLE_DB_USER=moodle_user \
  MOODLE_DB_PASS=xxxxx

# Recommended Moodle setting
# Moodle expects max_input_vars >= 5000
dokku config:set moodle PHP_INI_MAX_INPUT_VARS=5000
```

## First run
1. Visit `https://lms.srv.pathirana.net` and complete the web installer.
2. Restart once so the generated `config.php` is persisted into `moodledata`.

```bash
dokku ps:restart moodle
```

## Manual config.php (one-time)
If you prefer to avoid env-based generation, create `config.php` manually in the persistent volume.
You do **not** need to repeat this after each deploy as long as `/var/www/moodledata` is preserved.

```bash
# Remove any existing config first
dokku run moodle rm -f /var/www/html/config.php /var/www/moodledata/config.php

# Create config.php in the persistent volume
dokku run moodle bash -lc 'cat > /var/www/moodledata/config.php <<'"'"'PHP'"'"'
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype = "pgsql";
$CFG->dblibrary = "native";
$CFG->dbhost = "10.50.0.1";
$CFG->dbname = "moodle_db";
$CFG->dbuser = "moodle_user";
$CFG->dbpass = "xxxxx";
$CFG->prefix = "mdl_";
$CFG->dboptions = array(
  "dbpersist" => 0,
  "dbport" => 5435,
  "dbsocket" => "",
  "dbcollation" => "utf8",
  // "sslmode" => "require", // uncomment if needed
);

$CFG->wwwroot = "https://lms.srv.pathirana.net";
$CFG->dataroot = "/var/www/moodledata";
$CFG->admin = "admin";
$CFG->directorypermissions = 02770;

// Reverse proxy / TLS termination
$CFG->reverseproxy = true;
$CFG->sslproxy = true;

require_once(__DIR__ . "/lib/setup.php");
PHP
'

# Copy into web root and fix ownership
dokku run moodle bash -lc 'cp /var/www/moodledata/config.php /var/www/html/config.php && chown www-data:www-data /var/www/html/config.php /var/www/moodledata/config.php'

# Restart
dokku ps:restart moodle
```

## Cron (required)
Run Moodle cron every minute. Example cron entry on the Dokku host:

```cron
* * * * * /usr/bin/php /var/www/html/admin/cli/cron.php
```

## Notes
- Update Moodle version by changing `MOODLE_VERSION` in `Dockerfile`.
- To enforce checksum verification, set `MOODLE_SHA256` in `Dockerfile` to the output of:
  `curl -fsSL https://download.moodle.org/download.php/direct/stable501/moodle-5.1.1.tgz | sha256sum`
- The Apache document root is set to `/var/www/html/public` to match Moodle 5.1+.
- `PG_URL` is parsed at container start by a small entrypoint wrapper, which exports `MOODLE_DB_*` for Moodle.
