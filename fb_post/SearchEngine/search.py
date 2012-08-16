#!/usr/bin/env python
print "Content-Type: text/html"
print
import cgi
import sys,os
import psycopg2
sys.path.append(os.path.abspath('../jsonParser/'))
from db_connection import openDb, closeDB
def search (query):
    try:
        (conn, cursor) = openDb(True, True)
    except psycopg2.Error, e:
        print "Error %d: %s" % (e.pgcode, e.pgerror)
        return -1
    try:
#        cursor.execute('''select post_row_id, freq, address, entropy from keyword_post_link as k_p_l JOIN (select row_id from keyword where word ~ %s) as t ON k_p_l.keyword_row_id = t.row_id order by entropy,freq desc limit 10''', (terms,))
        cursor.execute(query)
        result = ''
        for record in cursor:
#            if entropy == 'Entropy':
            result += '''
                <tr>
                    <td><a href=%s>%s</a></td> <td>%s</td> <td>%s</td> <td>%s</td> <td>%s</td> <td>%s</td>
                </tr>'''%(str(record[1]),str(record[1])[:50],str(record[2]),str(record[3]),str(record[4]),str(record[5]),str(record[6]) )
#            else:
#                result += '''
#                    <tr>
#                        <td><a href=%s>%s</a></td> <td>%s</td>
#                    </tr>'''%(str(record[2]),str(record[2])[:50],str(record[1]))
        return result
    except psycopg2.Error, e:
        closeDB(conn, cursor)
        print "*********Database************Error %s: %s\n" % (e.pgcode, e.pgerror)
        return -1

form = cgi.FieldStorage()
results = []
terms = ""

try:
    if form.has_key("terms"):
        terms = form.getvalue("terms")
        words = terms.split()
        query = '''select distinct post_row_id, address, freq, entropy, shares_count, likes_count, comments_count from search as s JOIN (select row_id from keyword where'''
        words_count = len(words)
        print 
        for each_word in words:
            query += ''' word ~* '%s' '''%each_word
            words_count -= 1
            if words_count > 0:
                query += ' %s '%form.getvalue("boolean")
            else:
                if form.getvalue("case") == 'Entropy':
                    query += ') as t ON s.keyword_row_id = t.row_id order by entropy desc,freq desc limit '
                elif form.getvalue("case") == 'Frequency':
                    query += ') as t ON s.keyword_row_id = t.row_id order by freq desc limit '
                elif form.getvalue("case") == 'Shares':
                    query += ') as t ON s.keyword_row_id = t.row_id where shares_count is not Null order by shares_count desc,freq desc limit '
                elif form.getvalue("case") == 'Likes':
                    query += ') as t ON s.keyword_row_id = t.row_id where likes_count is not Null order by likes_count desc,freq desc limit '
                elif form.getvalue("case") == 'Comments':
                    query += ') as t ON s.keyword_row_id = t.row_id where comments_count is not Null order by comments_count desc,freq desc limit '
        
        query += str(form.getvalue("How Many"))                       
        results = search (query)
        print """\
        <html>
        <head><title>Search Result </title></head>
        <body>
        Search Result for <h2>%s</h2> based on %s
        <table border="1">
            <tr>
                <th>Post link</th>
                <th>Frequency</th>
                <th>Entropy</th>
                <th>Shares Count</th>
                <th>Likes Count</th>
                <th>Comments Count</th>
            </tr>
            %s
        </table>
        </body>
        </html>
        """%(terms, form.getvalue("case"),results)
    else:
        # This is a little bit of test code.  This will never be called
        # when you call this class within your browser.  You probably want
        # to remove this before putting this into production.
        terms = "red blue three"
#        results = search("red blue three", OR, CASE_SENSITIVE, listdir(BASE_DIR))

#    doresultspage(terms, results)
except NameError:
    print "There was an error understanding your search request.  Please press the back button and try again."
except:
    print "Really Unexpected error:", sys.exc_info()[0]