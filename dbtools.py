import psycopg2
import json

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

from papertools import *
def push_paper(paperobj, connection = None):
    """paperobj {title: str < 512, desc: str, link: str, tags: [str <128], doi: str}-> TypeError, ValueError (Duplication or FieldIndex), psycopg2.error"""
    if not connection:
        global myConnection
        connection = myConnection
    if connection == None:
        raise psycopg2.InterfaceError("No connection made")

    checkedpaper = check_paper(paperobj)

    id = None
    with connection.cursor() as cur:
        cur.execute("""
            INSERT INTO papers (title,
                                description,
                                link,
                                doi)
            VALUES (%s, %s, %s, %s) RETURNING id
            )""", (checkedpaper['title'], checkedpaper['desc'], checkedpaper))
        id = cur.fetchone()
        if checkedpaper['tags'] and id:
            sendstr = cur.mogrify("""INSERT INTO tags (paper, tagname) values (%s""", (id,))
            cur.execute(sendstr + ", %s)", checkedpaper['tags'])
    connection.commit()
    return id

def fetched_to_papers(fetched):
    """[(id, title, desc, link, [tags], doi)...] -> {id: {paperfields}}"""
    papers = {}
    for paper_tuple in fetched:
        id = paper_tuple[0]
        tags = paper_tuple[4]
        if tags == [None]:
            tags = None
        papers[id] = {'title': paper_tuple[1],
                      'desc': paper_tuple[2],
                      'link':paper_tuple[3],
                      'tags': tags,
                      'doi':paper_tuple[5]}
        # forgot to return value
    return papers

def get_all_papers(connection = None):
    if not connection:
        global myConnection
        connection = myConnection
    if connection == None:
        raise psycopg2.InterfaceError("No connection made")

    papers = {}
    with connection.cursor() as cur:
        cur.execute("""
            SELECT papers.id,
                   papers.title,
                   papers.description,
                   papers.link,
                   array_agg(tags.tagname),
                   papers.doi
            FROM papers LEFT JOIN tags on tags.paper = papers.id
            GROUP BY papers.id""")
        return fetched_to_papers(cur.fetchall())
            # have to look up how to aggregate tags

def setup_tables(connection = None):
    if not connection:
        global myConnection
        connection = myConnection
    if connection == None:
        raise psycopg2.InterfaceError("No connection made")
    with connection.cursor() as cur:
        cur.execute("""
            create table if not exists papers (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT DEFAULT NULL,
                link TEXT DEFAULT NULL,
                doi TEXT DEFAULT NULL,
                added timestamp DEFAULT CURRENT_TIMESTAMP,
                updated timestamp DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (link, doi),
                CHECK (link IS NOT NULL or doi IS NOT NULL)
            )""")
        cur.execute("""
            create table if not exists categories (
                id SERIAL,
                name varchar(128) PRIMARY KEY,
                description TEXT DEFAULT NULL,
                parent varchar(128) DEFAULT NULL references categories(name) ON DELETE SET NULL,
                added timestamp DEFAULT CURRENT_TIMESTAMP,
                updated timestamp DEFAULT CURRENT_TIMESTAMP
        )""")
        cur.execute("""
            create table if not exists tags (
                id SERIAL,
                paper integer NOT NULL REFERENCES papers (id) ON DELETE CASCADE,
                tagname varchar(128) NOT NULL,
                added timestamp DEFAULT CURRENT_TIMESTAMP,
                updated timestamp DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (paper, tagname)
            )""")
        connection.commit()

def load_test_papers(connection=None):
        if not connection:
            global myConnection
            connection = myConnection
        if connection == None:
            raise psycopg2.InterfaceError("No connection made")
        with connection.cursor() as cur:
            cur.executemany("""
                insert into papers (title, description, link)
                values (%s, %s, %s)""", (("Title 1", None, "http://1"),
                                         ("Title 2", "Lolblah", "http://2"),
                                         ("Title 3", "LLOL", "http://3")))
            cur.execute("""
                insert into papers (title, doi)
                values ('Title 4', '1023.234123/blasdh234234')""")
            cur.execute("""
                insert into tags (paper, tagname)
                values (2, 'taggedy tag'), (2, 'super taggedy'),
                       (2, 'tagalag'), (4, 'taggedy tag')""")
        connection.commit()



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
    myConnection = load_DB(login_info['testML'])
    print "Test connection made!"
    print "..."
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
