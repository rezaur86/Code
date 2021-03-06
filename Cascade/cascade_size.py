import sys
from sets import Set
import csv
import array
import operator
import threading
import time

f = open(sys.argv[1], "r")

vertices = {}
v_ids = array.array('L')
vertex_count = 0
activities = []
activities_count = 0
seeds = []
seeds_count = 0

pool_of_seeds = []
pool_of_seeds_lock = threading.RLock()

cascade_sizes = []
cascade_sizes_lock = threading.RLock()

batch_size = 10000
thread_count = 24
thread_ids = []

ODEG = 0
INDEG = 1
# pre-processing: make lists of sender_ids and recipient_ids in the original graph
for line in f:
    splits = line.split()
    sender = long(splits[0].strip())
    recv = long(splits[1].strip())
    
    if vertices.has_key(sender):
        vertices[sender][ODEG] += 1
    else:
        vertices[sender] = [1,0] #outdeg = 1, indeg = 0
        pool_of_seeds.append(activities_count)
        seeds_count += 1
    if vertices.has_key(recv):
        vertices[recv][INDEG] += 1
    else:
        vertices[recv] = [0,1] #outdeg = 0, indeg = 1
    
    activities.append([sender, recv]) # time of this activity is activities_count 
    activities_count += 1

f.close()
#vertices = {} # free some memory

print activities_count
print seeds_count

class CascadeThread (threading.Thread):
    def __init__(self, threadID, name, pool_of_seeds):
        super(CascadeThread, self).__init__()
        self.threadID = threadID
        self.name = name
        self.pool_of_seeds = pool_of_seeds
    def run(self):
        print "Starting " + self.name
        CascadeWorker()
        print "Exiting " + self.name

def CascadeWorker():
    to_do = True
    while to_do:
        seeds_batch = {}
        pool_of_seeds_lock.acquire()
        if len(pool_of_seeds) > 0:
            new_seed_act_id = pool_of_seeds.pop(0)
        else:
            to_do = False
        pool_of_seeds_lock.release()
        if to_do == False:
            break
        seeds_batch[activities[new_seed_act_id][0]] = 0
#        seeds_batch.append(new_seed_act_id)
        batch_counter = batch_size - 1
#        min_seed_act_time = seeds[new_seed_id][1]
        min_seed_act_time = new_seed_act_id
        while batch_counter > 0:
            pool_of_seeds_lock.acquire()
            if len(pool_of_seeds) > 0:
                new_seed_act_id = pool_of_seeds.pop(0)
            else:
                to_do = False
                batch_counter = 0
            pool_of_seeds_lock.release()
            if batch_counter == 0:
                break
            seeds_batch[activities[new_seed_act_id][0]] = 0
#            seeds_batch.append(new_seed_act_id)
            batch_counter -= 1
        CascadeBuilder(min_seed_act_time, seeds_batch)

def CascadeBuilder(min_seed_act_time, target_seeds):
    participation = {}
    participation_at_depth = {}
#    target_seeds = {}
    target_seeds_depth = {}
    for i in range(min_seed_act_time, activities_count):
        if target_seeds.has_key(activities[i][0]) == True:
#        if i in seeds_batch:
            if participation.has_key(activities[i][0]) == False:
                participation[activities[i][0]] = Set([i])#activities[i][0]])
                participation_at_depth[activities[i][0]] = {}
                participation_at_depth[activities[i][0]][i] = 0 #activities[i][0]] = 0
#                target_seeds[activities[i][0]] = 0
                target_seeds_depth[activities[i][0]] = 0
            if participation.has_key(activities[i][1]) == False:
                participation[activities[i][1]] = participation[activities[i][0]].copy()
                participation_at_depth[activities[i][1]] = participation_at_depth[activities[i][0]].copy()
                for each_seed in participation_at_depth[activities[i][1]].keys():
                    participation_at_depth[activities[i][1]][each_seed] += 1
            else:
                participation[activities[i][1]] = participation[activities[i][1]].union(participation[activities[i][0]])
                for each_seed in participation[activities[i][1]]:
                    if participation_at_depth[activities[i][1]].has_key(each_seed) and participation_at_depth[activities[i][0]].has_key(each_seed):
                        participation_at_depth[activities[i][1]][each_seed] = max(participation_at_depth[activities[i][1]][each_seed], participation_at_depth[activities[i][0]][each_seed]) + 1
                    else:
                        if participation_at_depth[activities[i][0]].has_key(each_seed):
                            participation_at_depth[activities[i][1]][each_seed] = participation_at_depth[activities[i][0]][each_seed] + 1
        else:
            if participation.has_key(activities[i][0]) == True:
                if participation.has_key(activities[i][1]) == False:
                    participation[activities[i][1]] = participation[activities[i][0]].copy()
                    participation_at_depth[activities[i][1]] = participation_at_depth[activities[i][0]].copy()
                    for each_seed in participation_at_depth[activities[i][1]].keys():
                        participation_at_depth[activities[i][1]][each_seed] += 1
                else:
                    participation[activities[i][1]] = participation[activities[i][1]].union(participation[activities[i][0]])
                    for each_seed in participation[activities[i][1]]:
                        if participation_at_depth[activities[i][1]].has_key(each_seed) and participation_at_depth[activities[i][0]].has_key(each_seed):
                            participation_at_depth[activities[i][1]][each_seed] = max(participation_at_depth[activities[i][1]][each_seed], participation_at_depth[activities[i][0]][each_seed]) + 1
                        else:
                            if participation_at_depth[activities[i][0]].has_key(each_seed):
                                participation_at_depth[activities[i][1]][each_seed] = participation_at_depth[activities[i][0]][each_seed] + 1
    for v_participates in participation.keys():
        for seed_v in participation[v_participates]:
            target_seeds[activities[seed_v][0]] += 1
        for seed_v in participation_at_depth[v_participates].keys():
            target_seeds_depth[activities[seed_v][0]] = max(target_seeds_depth[activities[seed_v][0]],participation_at_depth[v_participates][seed_v])
    for a_seed in target_seeds.keys():
        cascade_sizes_lock.acquire()
        cascade_sizes.append([a_seed, target_seeds[a_seed], target_seeds_depth[a_seed]])
        cascade_sizes_lock.release()

# Create threads
for i in range(thread_count):
    thread = CascadeThread(i, "Thread-"+str(i), pool_of_seeds)
    thread_ids.append(thread)
    thread.start()    # Start new Threads

while True:
    if len(pool_of_seeds) > 0:
        print len(pool_of_seeds)*100/seeds_count,'%'#, pool_of_seeds[0:5]
        time.sleep(20)
    else:
        break
for a_thread in thread_ids:
    a_thread.join()
        
#pool_of_seeds.join()
print "Exiting Main Thread"
o_seeds_sizes =  open (sys.argv[2], "w")
writer = csv.writer(o_seeds_sizes, quoting=csv.QUOTE_MINIMAL)
cascade_sizes.sort(key=operator.itemgetter(1), reverse=True)
writer.writerows(cascade_sizes)
o_seeds_sizes.close()
