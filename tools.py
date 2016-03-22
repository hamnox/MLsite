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

            # don't know a way to exit.
