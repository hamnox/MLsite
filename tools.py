# okay so, I need to build a little tool
#"""err: first have to think of a bunch of little tools and DECISION PARALYSIS"""
#"""err: want to immediately switch to pycharm"""
#"""err: have to look up how to do json save stuff"""

# saving information to JSON
__SAVEFILENAME = "papers.json"

import json

def save_to_file(data):
    with open(__SAVEFILENAME, 'w') as outfile:
        json.dump(data, outfile)
#    """err: don't know about error-catching"""
#    """err: no time to write tests"""
#    """err: think I should use atomic write"""



# def save_to_(data



# wasted time deleting all the gemfile stuff
