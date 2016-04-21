#!/usr/bin/env bash
psql -c 'DROP DATABASE ml_db_test;'
psql -c "create database ml_db_test with encoding = 'UTF8';"

#TODO: backupDB.sh
#TODO: restorebackupDB.sh
#TODO: remove all user info