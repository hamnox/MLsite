from flask import Flask, request, url_for, render_template
from dbtools import load_db, get_all_notes
from papertools import split_tags
import json

app = Flask(__name__)

login_info = json.load(open("login_info.json","r"))
myConnection = load_db(login_info['ML'])

@app.route('/')
def get_all():
    return_val = ""
    notes = get_all_notes(myConnection)
    if not notes:
        return "No papers here"
    for id, note in notes:
        add_on = """
            <article id="%s"><h3>%s</h3>
            <div class="desc">%s</div>
            <div class="link">%s</div>
            <div class="tags">%s</div>
            </article>""" % (id, note['title'],
                                 note['desc'],
                                 note['urls'],
                                 note['tags'])

        return_val += add_on

    return "<html>%s</html>" % return_val
# TODO: make a table

@app.route('/make', methods=["POST","GET"])
def serve():
    if request.method == 'POST':
        try:
            # TODO: get all of these things
            paper_obj = {'title': request.form['title'],
                        'desc': request.form['desc'],
                        'link': request.form['link'],
                        'tags': split_tags(request.form['categories']),
                        'doi':  request.form['doi']}
            paper_id = push_paper(paper_obj, connection=myConnection)
            return "Paper id", paper_id
        except (TypeError, ValueError) as e:
            return e
    else:
        return render_template('MakePaperForm.html')

import atexit
@atexit.register
def close_connections():
    if myConnection != None:
        myConnection.close()


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)
