import re

def validate_doi(doi):
    if not doi:
        return None
    """return doi-string if doi is valid, false if invalid"""
    result = re.findall('\\b(?:doqi:)?(10[.][0-9]{3,}[.a-zA-Z0-9-._;()/]*)', str(doi))
    if len(result) == 1:
        if doi == result[0] or doi[4:] == result[0]:
            return result[0]
    return False

    # always truncate the doi

def validate_link(link):
    if not link:
        return None
    if link != str(link):
        return False
        # title: str, desc: str, link: str, tags: [str < 128], doi: str
    "return valid link"
    result = re.findall('((?:^https:\\/\\/.*?\\.\\S*)|(?:^http:\\/\\/.*?\\.\\S*)|(?:^www\\..*?\\.\\S*))', link.decode('utf-8', 'ignore'))
    if len(result) == 1 and result[0] == link:
        if result[0][:4] == "http":
            return result[0]
        else:
            return "http://" + result[0]
        # if link[0:7] == "http://" or link[0:8]=

    return False

def validate_title(title):
    # title: str, desc: str, link: str, tags: [str < 128], doi: str
    result = str(title)
    if title != str(title) or len(title) < 1:
        return False
    return str(title)

def validate_desc(desc):
    if desc == None or desc == "":
        return None
    if desc != str(desc) or len(desc) < 1:
        return False
    return str(desc)

# take a comma or space delimited string, return a list of tags

def split_tags(string):
    if "," in string:
        string = string.replace(", ", ",")
        return string.split(",")
    else:
        return string.split(" ")

def validate_tags(tags):
    if not tags:
        return None
    result = tags
    if tags == str(tags):
        if len(result) < 1:
            return None
        result = [tags]
    try:
        if len(result) < 1:
            return None
        for element in result:
            if element != str(element) or len(element) < 1 or len(element) > 128:
                return False
        else:
            return list(result)
    except TypeError:
        return False
    # tags = [str, ..] or None... can handle a ""

def check_paper(paperobj):
    result = {}

    if 'link' not in paperobj and 'doi' not in paperobj:
        raise ValueError("No doi or link")

    result['title'] = validate_title(paperobj.get('title', None))
    result['desc'] = validate_desc(paperobj.get('desc',None))
    result['link'] = validate_link(paperobj.get('link', None))
    result['doi'] = validate_doi(paperobj.get('doi', None))
    result['tags'] = validate_doi(paperobj.get('tags', None))

    for key, item in result.items():
        if item == False:
            raise ValueError("Invalid %s: %s" % (key, paperobj.get(key, None)))

    return result
        # https://docs.python.org/2/library/stdtypes.html#truth-value-testing
        # I certainly wish I knew a good way to always be checking for unicode bull!@$(


def tests():

    def test_dois():
        assert validate_doi("") == None
        assert validate_doi(None) == None
        assert validate_doi(1.23) == False
        assert validate_doi("doi:10.1513/pats.200402-016MS Title descriptor followed by") == False
        assert validate_doi("doi:10.1513/pats.200402-016MS") == "10.1513/pats.200402-016MS"
        assert validate_doi("publication date") == False
        assert validate_doi("10.1046/j.1445-2197.2003.02820.x") == "10.1046/j.1445-2197.2003.02820.x"
        assert validate_doi("Dissertation 10.2986/tren.009-0347") == False
    test_dois()

    def test_links():
        assert validate_link("") == None
        assert validate_link(None) == None
        assert validate_link(1.23) == False
        assert validate_link("https://foo.com") == "https://foo.com"
        assert validate_link("http://www.foo.com/blah_blah") == "http://www.foo.com/blah_blah"
        assert validate_link("https://foo.com/blah_blah_(wikipedia)") == "https://foo.com/blah_blah_(wikipedia)"
        assert validate_link("www.example.com/wpstyle/?p=364") == "http://www.example.com/wpstyle/?p=364"
        assert validate_link("http://code.google.com/events/#&product=browser") == "http://code.google.com/events/#&product=browser"
        assert validate_link("http://3628126748") == False
        assert validate_link("foo.com") == False
        assert validate_link("http://userid:password@example.com:8080") == "http://userid:password@example.com:8080"
        assert validate_link("userid:password@example.com:8080") == False
    test_links()

    def test_title_and_desc():
        # validate_title()
        assert validate_title("") == False
        assert validate_title(None) == False
        assert validate_title(1.23) == False
        assert validate_title("This is a title.") == "This is a title."
        assert validate_title(u"This is a title.") == "This is a title."
        # validate_desc()
        assert validate_desc("") == None
        assert validate_desc(None) == None
        assert validate_desc(1.23) == False
        assert validate_desc("This is a description.") == "This is a description."
        assert validate_desc(u"This is a description.") == "This is a description."
    test_title_and_desc()

    def test_split_tags():
        assert split_tags("asdf, fjfjf, rururu") == ["asdf", "fjfjf", "rururu"]
        assert split_tags("asdf, fjfjf,rururu") == ["asdf", "fjfjf", "rururu"]
        assert split_tags("asdf fjfjf rururu") == ["asdf", "fjfjf", "rururu"]
        assert split_tags("asinglething") == ["asinglething"]
        assert split_tags("") == [""]

    def test_tags():
        assert validate_tags("") == None
        assert validate_tags(()) == None
        assert validate_tags([]) == None
        assert validate_tags(1.23) == False
        assert validate_tags("tag") == ["tag"]
        assert validate_tags(["tag1", "tag2"]) == ["tag1", "tag2"]
        assert validate_tags(["tag1", "tag2"]) == ["tag1", "tag2"]
        assert validate_tags(("tag1", "tag2")) == ["tag1", "tag2"]
        assert validate_tags([1.23]) == False
        assert validate_tags([""]) == False
        assert validate_tags(["asdf", None]) == False
        # 128 chars
        assert validate_tags([
            "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque pen",
            "tag2"]) == ["Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque pen",
                         "tag2"]
        # 129 chars
        assert validate_desc([
        "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque pen.",
        "tag2"]) == False
    test_tags()


    def test_check_paper():
        pmin = {'title': 'This Title',
                'doi': 'doi:10.1513/pats.200402-016MS'}
        pminplus = {'title': 'This Title',
                    'desc': None,
                    'link': None,
                    'tags': None,
                    'doi': '10.1513/pats.200402-016MS'}
        pquotesbad = {'title': 'Another Title',
                'desc': "",
                'link': "",
                'tags': "",
                'doi': ""}
        pquotesgood = {'title': 'Another Title',
                              'desc': "",
                              'link': "http://www.ubercool.com",
                              'tags': "",
                              'doi': ""}
        try:
            check_paper({})
        except ValueError as e:
            assert e.message in ["Invalid title: False", "No doi or link"]
        try:
            check_paper({'title':'asdf'})
        except ValueError as e:
            assert e.message == "No doi or link"

        try:
            check_paper({'link':'http://www.cool.com/'})
        except ValueError as e:
            assert e.message == "Invalid title: None"

        try:
            check_paper({'title': None, 'doi': None, 'link': None})
        except ValueError as e:
            assert e.message in ["Invalid title: None", "No doi or link"]

        try:
            check_paper({'title': "", 'link':'http://www.cool.com/'})
        except ValueError as e:
            assert e.message == "Invalid title: "

        try:
            check_paper(pquotesbad)
        except ValueError as e:
            assert e.message == "No doi or link"

        assert check_paper(pmin) == pminplus
        assert check_paper(pminplus) == pminplus
        assert check_paper(pquotesgood) == {'title': 'Another Title',
                                            'desc': None,
                                            'link': "http://www.ubercool.com",
                                            'tags': None,
                                            'doi': None}

        pbad = {'title': 'Another Title',
                          'desc': "",
                          'link': "not really a link",
                          'tags': ["testing this, testing that"],
                          'doi': ""}
        try:
            check_paper(pbad)
        except ValueError as e:
            assert e.message == 'Invalid link: not really a link'

    test_check_paper()
    test_split_tags()



if __name__ == "__main__":
    tests()