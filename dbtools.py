import psycopg2
import json
from papertools import *

myConnection = None

def load_DB(login_obj):
    global myConnection
    """{'hostname'=str, 'username'=str, 'password'=str, 'database'=str}"""
    # TODO: also let it use the host and user and db strings
    # if connection doesn't exist, initdb
    # stub
    if myConnection != None:
        myConnection.close()
    myConnection = psycopg2.connect(host=login_obj['hostname'],
                                    user=login_obj['username'],
                                    password=login_obj['password'],
                                    dbname=login_obj['database'])
    # damn this needs to be a thread or something.
    return myConnection

# def push_paper(paperobj, connection = None):
#     """paperobj {title: str < 512, desc: str, link: str, tags: [str <128], doi: str}-> TypeError, ValueError (Duplication or FieldIndex), psycopg2.error"""
#     if not connection:
#         global myConnection
#         connection = myConnection
#     if connection == None:
#         raise psycopg2.InterfaceError("No connection made")
#
#     checkedpaper = check_paper(paperobj)
#
#     id = None
#     with connection.cursor() as cur:
#         cur.execute("""
#             INSERT INTO papers (title,
#                                 description,
#                                 link,
#                                 doi)
#             VALUES (%s, %s, %s, %s) RETURNING id
#             )""", (checkedpaper['title'], checkedpaper['desc'], checkedpaper))
#         id = cur.fetchone()
#         if checkedpaper['tags'] and id:
#             sendstr = cur.mogrify("""INSERT INTO tags (paper, tagname) values (%s""", (id,))
#             cur.execute(sendstr + ", %s)", checkedpaper['tags'])
#     connection.commit()
#     return id
# 
# def fetched_to_papers(fetched):
#     """[(id, title, desc, link, [tags], doi)...] -> {id: {paperfields}}"""
#     papers = {}
#     for paper_tuple in fetched:
#         id = paper_tuple[0]
#         tags = paper_tuple[4]
#         if tags == [None]:
#             tags = None
#         papers[id] = {'title': paper_tuple[1],
#                       'desc': paper_tuple[2],
#                       'link':paper_tuple[3],
#                       'tags': tags,
#                       'doi':paper_tuple[5]}
#         # forgot to return value
#     return papers
# 
def get_all_notes(connection = None):
    if not connection:
        global myConnection
        connection = myConnection
    if connection == None:
        raise psycopg2.InterfaceError("No connection made")

    notes = {}
    with connection.cursor() as cur:
        # cur.execute("""
        #     SELECT note.id,
        #            note.name,
        #            note.description,
        #            link.url,
        #            array_agg(tag.tagname),
        #            array_agg(category.name)
        #     FROM note LEFT JOIN tag ON tag.note = note.id
        #             LEFT JOIN category ON tag.category = category.id
        #             LEFT JOIN link ON note.id = link.note
        #     GROUP BY note.id""")
        cur.execute("""
                SELECT note.id,
                       note.name,
                       note.description,
                       array_agg(link.url),
                       array_agg(tag.tagname)
                FROM note LEFT JOIN tag ON tag.note = note.id
                        LEFT JOIN link ON note.id = link.note
                GROUP BY note.id, link.url""")
        return fetched_to_notes(cur.fetchall())
            # have to look up how to aggregate tags

def get_rid_of_nones(l):
    return_list = []
    for item in l:
        if not item:
            return_list.append(item)
    if return_list == []:
        return None
    else:
        return return_list

def fetched_to_notes(fetched):
    """[(id, title, desc, link, [tags], doi)...] -> {id: {notefields}}"""
    notes = {}
    for note_tuple in fetched:
        id = note_tuple[0]
        notes[id] = {'title': note_tuple[1],
                      'desc': note_tuple[2],
                      'link': get_rid_of_nones(note_tuple[3]),
                      'tags': get_rid_of_nones(note_tuple[4])}
    return notes.items()[1:10]

import atexit
@atexit.register
def close_connections():
    if myConnection != None:
        myConnection.close()

# TODO: make a set up tear down for testing ML functions

# TODO: insert some test users: I think this will best work from the other end

# http://stackoverflow.com/questions/3195125/copy-a-table-from-one-database-to-another-in-postgres

if __name__ == "__main__":
    login_info = json.load(open("login_info.json","r"))
    myConnection = load_DB(login_info['ML'])
    print "Test connection made!"
    print "..."
    print get_all_notes(myConnection)
    # setup_tables()
    # print "Tables set up!"
    # load_test_papers()
    # print "Test papers loaded!"
    if myConnection == None:
        print "Where did the connection go?"
    else:
        myConnection.close()
    myConnection = None
    print "Test connection closed!"
