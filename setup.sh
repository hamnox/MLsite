#!/usr/bin/env bash

# TODO: make this be a python prompt, to generate login_info file
createuser --createdb --username postgres --pwprompt --no-createrole ml_user
createdb -U ml_user -E UTF8 ml_db
                                
psql -U ml_user -d ml_db -c "CREATE TABLE IF NOT EXISTS category (
                                id SERIAL PRIMARY KEY,
                                name VARCHAR(128) NOT NULL,
                                description TEXT DEFAULT NULL,
                                parent INTEGER REFERENCES category(id)
                                    ON DELETE SET NULL DEFAULT NULL,
                                added timestamp DEFAULT CURRENT_TIMESTAMP,
                                updated timestamp DEFAULT CURRENT_TIMESTAMP )"


psql -U ml_user -d ml_db -c "CREATE TABLE IF NOT EXISTS note (
                                id SERIAL PRIMARY KEY,
                                name VARCHAR(128) DEFAULT NULL,
                                description TEXT UNIQUE NOT NULL,
                                added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP )"

psql -U ml_user -d ml_db -c "CREATE TABLE IF NOT EXISTS link (
                                id SERIAL PRIMARY KEY,
                                note INTEGER NOT NULL REFERENCES note(id),
                                url TEXT NOT NULL,
                                added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                UNIQUE (note, url)"

psql -U ml_user -d ml_db -c "CREATE TABLE IF NOT EXISTS tag (
                                id SERIAL PRIMARY KEY,
                                note INTEGER NOT NULL REFERENCES note(id)
                                    ON DELETE CASCADE,
                                category INTEGER REFERENCES category(id)
                                    ON DELETE SET NULL DEFAULT NULL,
                                tagname VARCHAR(128) NOT NULL,
                                added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
                                UNIQUE (note, tagname),
                                UNIQUE (note, category))"

psql -U ml_user -d ml_db -c "CREATE TABLE IF NOT EXISTS paper (
                                id SERIAL PRIMARY KEY,
                                title TEXT DEFAULT NULL,
                                summary TEXT DEFAULT NULL,
                                note INTEGER DEFAULT NULL REFERENCES note(id),
                                comment TEXT DEFAULT NULL,
                                arxivid TEXT UNIQUE DEFAULT NULL,
                                doi TEXT UNIQUE DEFAULT NULL,
                                journalref TEXT DEFAULT NULL,
                                link TEXT DEFAULT NULL,
                                authorsaffil TEXT[][]  DEFAULT NULL,
                                categoryterms TEXT[] DEFAULT NULL,
                                published TIMESTAMP DEFAULT NULL,
                                added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                UNIQUE (doi, title)); "
                                


