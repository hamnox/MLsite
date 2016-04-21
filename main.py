from flask import Flask, request, url_for # render_template
from dbtools import load_DB, get_all_papers
import json

app = Flask(__name__)

login_info = json.load(open("login_info.json","r"))
myConnection = load_DB(login_info['ML'])

@app.route('/')
def get_all():
    retval = ""
    papers = get_all_papers(myConnection)
    if not papers:
        return "No papers here"
    for id, paper in papers.items():
        addon = """
            <article id="%s"><h3 id= >%s</h3>
            <div class="desc">%s</div>
            <div class="link">%s</div>
            <div class="tags">%s</div>
            <div class="doi">%s</div>
            </article>""" % (id, paper['title'],
                                 paper['desc'],
                                 paper['link'],
                                 paper['tags'],
                                 paper['doi'])

        retval = retval + addon

    return "<html>%s</html>" % retval
# TODO: make a table


import atexit
@atexit.register
def close_connections():
    if myConnection != None:
        myConnection.close()


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)