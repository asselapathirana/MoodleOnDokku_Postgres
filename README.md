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
  PG_URL=postgresql://moodle_user:xxxxx@10.50.0.1:5435/moodle_db

# Recommended Moodle setting
# Moodle expects max_input_vars >= 5000
dokku config:set moodle PHP_INI-max_input_vars=5000
```

## First run
1. Visit `https://lms.srv.pathirana.net` and complete the web installer.
2. Restart once so the generated `config.php` is persisted into `moodledata`.

```bash
dokku ps:restart moodle
```

## Cron (required)
Run Moodle cron every minute. Example cron entry on the Dokku host:

```cron
* * * * * /usr/bin/php /var/www/html/admin/cli/cron.php
```

## Notes
- Update Moodle version by changing `MOODLE_VERSION` and `MOODLE_SHA256` in `Dockerfile`.
- The Apache document root is set to `/var/www/html/public` to match Moodle 5.1+.
