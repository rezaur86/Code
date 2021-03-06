import psycopg2

db_name = 'rezaur_db'
db_server = 'localhost'
db_namespace = 'fb_post'

def openDb(auto_commit=True, change_schema=True):
    try:
        conn = psycopg2.connect(database=db_name, user='rezaur', password='acer1986', host=db_server, port=5432)
        conn.autocommit = auto_commit
        cur = conn.cursor()
        if change_schema:
            cur.execute('set search_path=%s,%s', (db_namespace, 'public'))
        return (conn, cur)
    except psycopg2.Error, e:
        print "Error %s: %s" % (e.pgcode, e.pgerror)
        conn.close()

def closeDB (conn, cursor):
    try:
        cursor.close()
        conn.close()
    except psycopg2.Error, e:
        print "Error %d: %s" % (e.pgcode, e.pgerror)