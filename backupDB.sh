#!/usr/bin/env bash

# old style:
now=$(date +"%Y%m%d_%H%M")
pg_dump ml_db > ml_backup_$now


# to transfer to a backupdb:
# psql -U ml_user -c 'DROP DATABASE ml_db_backup;'
# psql -U ml_user -c "create database ml_db_backup with encoding = 'UTF8';"
# pg_dump -t note ml_db | psql ml_db_backup
# pg_dump -t link ml_db | psql ml_db_backup
# pg_dump -t category ml_db | psql ml_db_backup
# pg_dump -t tag ml_db | psql ml_db_backup
# pg_dump -t paper ml_db | psql ml_db_backup