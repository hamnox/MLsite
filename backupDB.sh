#!/usr/bin/env bash

pg_dump ml_db_backup > last_ml_backup
psql -c 'DROP DATABASE ml_db_backup;'
psql -c "create database ml_db_backup with encoding = 'UTF8';"

pg_dump -t papers ml_db | psql ml_db_backup
pg_dump -t tags ml_db | psql ml_db_backup
pg_dump -t categories ml_db | psql ml_db_backup