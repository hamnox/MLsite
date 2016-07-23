#!/usr/bin/python

# okay so, I need to build a little tool
#"""err: first have to think of a bunch of little tools and DECISION PARALYSIS"""
#"""err: want to immediately switch to pycharm"""
#"""err: have to look up how to do json save stuff"""

# saving information to JSON
__SAVEFILENAME = "papers.json"

import json

def save_to_file(data):
    atomic_write(__SAVEFILENAME, json.dumps(data))

# had to look up kwargs
def startloop(**kwargs):
# stub that isn't valid
    return kwargs
    """takes a keyword arguments with their validation functions
        -> returns a list of what the user replied for each one."""
    for key, validation in kwargs:
        user_response = raw_input(" Keyword: ")
        while validation(user_response):
            user_response = raw_input("  Try again: ")

            # don't know a way to capture exit attempts


# DATATYPE: str, str, httpstr, categorystr or [categorystr..s], str -> Paper, false
def make_paper(title, desc=None, link=None, tags=None, doi=None):
    """takes a paper and returns an unsaved paper object or errors if any of the
       items are formatted incorrectly. Description, tags, and (DOI or Link) can be blank"""
    # stub
    # http://blog.apastyle.org/apastyle/digital-object-identifier-doi/
    # must have title
    # must have link or doi
    # turn "", [], None -> None
    # validate link
    # validate doi
    # validate (or create?) category
    return ["title",
            "this is a description of the paper",
            "http://www.fakeaddress.io/paper.pdf",
            ['speed', 'basics'],
            "10.1038/nature14236"] # TODO: reformat to Dictionary



# DataStorage, paper -> intid raise ValueError, IOError, DuplicateError?
def save_paper(db, paper):
    """takes paper information and saves it to database"""
    # stub
    return 1
    

# construct db
# load db
# save db
# backup db


import os
def atomic_write(filename, text):
    f = open('_tempfile_', 'w')
    f.write(text)
    # make sure that all data is on disk
    # see http://stackoverflow.com/questions/7433057/is-rename-without-fsync-safe
    f.flush()
    os.fsync(f.fileno()) 
    f.close()

    os.rename('_tempfile_', filename)



# ----- WISHLIST -----
# port_database: DB -> jsonfile
# backup db (periodically called)
# load db (at start)
# initdb, teardowndb

"""
# https://www.a2hosting.com/kb/developer-corner/postgresql/connecting-to-postgresql-using-python
# Simple routine to run a query on a database and print the results:
def doQuery( conn ) :
    cur = conn.cursor()

    cur.execute( "SELECT fname, lname FROM employee" )

    for firstname, lastname in cur.fetchall() :
        print firstname, lastname


print "Using psycopg2"

print "Using PyGreSQL"
import pgdb
myConnection = pgdb.connect( host=hostname, user=username, password=password, database=database )
doQuery( myConnection )
myConnection.close()
"""

# TODO: assert login_info.json exists or create it with defaults
import dbtools

login_info = json.load(open("login_info.json","r"))
dbtools.load_db(login_info['testML'])
    

# TODO: find the thing that opens on exist, use it to close the connection
# https://docs.python.org/2/library/atexit.html







# ----- TESTS -----

def test_make_paper():
    # str, str, httpstr, categorystr or [categorystr..s], str -> Paper, false
    """takes a paper and returns an unsaved paper object or false"""

    fakepaper_1 = ["title",
            "this is a description of the paper",
            "http://www.fakeaddress.io/paper.pdf",
            ['speed', 'basics'],
            "10.1038/nature14236"]
    fakepaper_2 = ["what's in a title",
            None,
            "http://www.fakeaddress.io/paper7pdf",
            None,
            "11.1038/nature13236"]
    fakepaper_3 = ["title me not",
            "this is weird",
            "http://www.fakeaddress.com/paper.html",
            ['fake-category'],
            "10.1037/rmh0000008"]

    # blanks are not okay
    try: 
        make_paper(None, None, None, None, None) == False
    except (TypeError, ValueError) as e:
        pass

    assert make_paper(fakepaper_1[0],
                            fakepaper_1[1],
                            fakepaper_1[2],
                            fakepaper_1[3],
                            fakepaper_1[4]) == fakepaper_1
    # blank description and tags are okay
    assert make_paper(fakepaper_2[0],
                            fakepaper_2[1],
                            fakepaper_2[2],
                            fakepaper_2[3],
                            fakepaper_2[4]) == fakepaper_2
    # equivalencies of None, "", []
    assert make_paper(fakepaper_2[0],
                            "",
                            fakepaper_2[2],
                            [],
                            fakepaper_2[4]) == fakepaper_2
    assert make_paper(fakepaper_2[0],
                            fakepaper_2[1],
                            fakepaper_2[2],
                            "",
                            fakepaper_2[4]) == fakepaper_2
    # fake categories are caught
    try:
        make_paper(fakepaper_3[0],
                            fakepaper_3[1],
                            fakepaper_3[2],
                            fakepaper_3[3],
                            fakepaper_3[4])
    except (TypeError, ValueError) as e:
        pass

    # DOI or Link can be blank
    assert make_paper("t", "d", None, None, "10.1037/rmh0000004") == [
                      "t", "d", None, None, "10.1037/rmh0000004"]
    assert make_paper("t", "d", "", None, "10.1037/rmh0000004") == [
                      "t", "d", None, None, "10.1037/rmh0000004"]
    assert make_paper("t", "d", "www.thiscoolness.me", None, None) == [
                      "t", "d", "www.thiscoolness.me", None, None]
    assert make_paper("t", "d", "https://cool.me", None, "") == [
                      "t", "d", "https://cool.me", None, None]

    # also need to test invalid DOIS, invalid links

def test_save_paper():
    # stub
    pass
