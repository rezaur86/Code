import json
FILE = open ("/home/rezaur/Downloads/all_followers_followees.txt", "r")
for json_line in FILE:
    onedata = json.loads(json_line)
    
FILE.close()
