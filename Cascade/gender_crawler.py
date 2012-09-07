#!/usr/bin/python
import os,sys
import csv
import re
import signal
import json
import time
import threading
import operator
import array
import pycurl
import cStringIO

THREAD_COUNT = 10
BATCH_SIZE = 1000
graph_url = "https://graph.facebook.com/"
error1 = re.compile(r"Calls to stream have exceeded the rate of 600 calls per 600 seconds")
error2 = re.compile(r"Application request limit reached")
error3 = re.compile(r"Unknown fields")


def extract_gender(data):
    batch_genders = []
    try:
        onedata = json.loads(data)
    except Exception as e:
        print "*********Json Loading Error************\n"
    for an_id in onedata.keys():
        if onedata[an_id].has_key("gender"):
            batch_genders.append((an_id,onedata[an_id]["gender"]))
    return batch_genders

def curl_request (url):
    response = cStringIO.StringIO()
    c = pycurl.Curl()
    c.setopt(c.URL, url)
    c.setopt(c.WRITEFUNCTION, response.write)
    c.setopt(c.NOSIGNAL, 1)
    c.perform()
    c.close()
    return response.getvalue()
    
class CrawlerThread (threading.Thread):
    def __init__(self, threadID, name):
        super(CrawlerThread, self).__init__()
        self.threadID = threadID
        self.name = name
    def run(self):
        print "Starting " + self.name
        UserInfoWorker()
        print "Exiting " + self.name

def UserInfoWorker():
    global output
    while True:
        batch = 0
        request_ids = ''
        batch_ids = []
        gender_absent_batch_ids = []
        with user_id_pop_lock:
            if len(user_ids) > 0:
                an_id = user_ids.pop(0)
                request_ids += str(an_id)
                batch_ids.append(an_id)
                batch += 1
            else:
                break
        while batch < BATCH_SIZE:
            with user_id_pop_lock:
                if len(user_ids) > 0:
                    an_id = user_ids.pop()
                    request_ids += ',' + str(an_id)
                    batch_ids.append(an_id)
                    batch += 1
                else:
                    break
        gender_url = graph_url + "?fields=gender&ids=" + request_ids
        try:
            gender_json = ''.join((curl_request(gender_url)).split('\n'))
            rerun1 = re.findall(error1,gender_json)
            rerun2 = re.findall(error2,gender_json)
            if rerun1 or rerun2:        
                time.sleep(600)
                gender_json = ''.join(curl_request(gender_url).split('\n'))
            rerun3 = re.findall(error3,gender_json)
            if rerun3:
                gender_absent_batch_ids.extend(batch_ids)
            
            batch_genders = extract_gender(gender_json)
            with output_lock:
                output.extend(batch_genders)
        except Exception, e:
            print "Curl Exception%s:"%e
            err_f = open ('error.txt', "a")
            err_f.write(gender_url+'\n')
            err_f.close()
            with user_id_pop_lock:
                user_ids.extend(batch_ids)
        time.sleep(10)

user_file = open(sys.argv[1], "r")
user_ids = []
user_id_pop_lock = threading.RLock()
for line in user_file:
    line = line.replace("\n","")    
    user_ids.append(long(line.strip()))    
user_file.close()

total_users = len(user_ids)
print "total user %s"%total_users
# Needs another lock to protect output
output = []
output_lock = threading.RLock()

thread_ids = []
for i in range(THREAD_COUNT):
    thread = CrawlerThread(i, "Thread-"+str(i))
    thread_ids.append(thread)
    thread.start()    # Start new Threads

while True:
    if len(user_ids) > 0:
        print len(user_ids)*100/total_users,'%'#, pool_of_seeds[0:5]
        time.sleep(20)
        if len(output) > 10000:
            with output_lock:
                o_gender_json = open (sys.argv[2], "a")
                writer = csv.writer(o_gender_json, quoting=csv.QUOTE_MINIMAL)
#                output.sort(key=operator.itemgetter(0), reverse=True)
                writer.writerows(output)
                o_gender_json.close()
                output = []
                
    else:
        break
for a_thread in thread_ids:
    a_thread.join()

if len(output) > 0:
    with output_lock:
        o_gender_json = open (sys.argv[2], "a")
        writer = csv.writer(o_gender_json, quoting=csv.QUOTE_MINIMAL)
        writer.writerows(output)
        o_gender_json.close()
        
print "Exiting Main Thread"
