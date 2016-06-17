#!/usr/bin/env bash

source env/bin/activate
./testDB_reset.sh

python main.py
