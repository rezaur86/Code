create table participate as (
select message.from_user_row_id as fb_user_row_id, message.fb_wall_row_id as group_row_id from message
UNION
select likedby.who_user_row_id as fb_user_row_id, message.fb_wall_row_id as group_row_id from likedby JOIN message on likedby.what_message_row_id = message.row_id
);

create table participate_count as (
select fb_user.id as user_id, count(participate.group_row_id) as participation_count from fb_user JOIN participate ON fb_user.row_id = participate.fb_user_row_id
	group by user_id having count(participate.group_row_id) > 1 order by participation_count desc
);

-------Users invoved in a particular community-----------------
create or replace view message_community as (select row_id from message where fb_wall_row_id = 1 or fb_wall_row_id = 2);
\copy ( select from_user_row_id from message_community JOIN message on message_community.row_id = message.row_id UNION select to_user_row_id from message_community JOIN message_to on message_community.row_id = message_to.message_row_id UNION select who_user_row_id from message_community JOIN likedby on message_community.row_id = likedby.what_message_row_id UNION select user_row_id from message_community JOIN tag on message_community.row_id = tag.message_row_id) to 'users_involved.txt'

For keith:
create table the_8_groups as (select m.* from message as m JOIN (select row_id from fb_user where id in (44473416732,153774071379194,131459315949,23294612872,5550296508,294421993905616,184749301592842,15704546335)) as f ON m.fb_wall_row_id = f.row_id);
\copy (select m2.row_id as row_id, m2.id as message_id, (select m1.id as parent_message_id from the_8_groups as m1 where m1.row_id = m2.parent_message_row_id), m2.name as name, m2.text as text, m2.created_time as created_time,(select f.id as from_user_id from fb_user as f where m2.from_user_row_id = f.row_id) from the_8_groups as m2) to 'keith_the_8_groups_message.csv' with delimiter ',' CSV quote '"';

\copy (select (select m.id from occupy_LA as m where m.row_id = l.what_message_row_id),(select f.id from fb_user as f where f.row_id = l.who_user_row_id) from likedby as l) to 'keith_occupy_LA_liked_by.csv';

Fox News:
create table fox_news as (select row_id,from_user_row_id,parent_message_row_id,created_time from message where fb_wall_row_id = 18560);
create table Fox_news_Interaction (from_user,to_user,message_time) as (
(select m1.from_user_row_id, (select m2.from_user_row_id from fox_news as m2 where m1.parent_message_row_id = m2.row_id), m1.parent_message_row_id, m1.created_time from fox_news as m1 )
UNION ( select m.from_user_row_id, l.who_user_row_id, m.parent_message_row_id, m.created_time from fox_news as m JOIN likedby as l ON m.row_id = l.what_message_row_id )
UNION ( select t.user_row_id, m.from_user_row_id, m.parent_message_row_id, m.created_time from fox_news as m JOIN tag as t ON m.row_id = t.message_row_id )
);
\copy (select from_user, to_user from fox_news_interaction order by message_time) to 'fox_news_in.txt' with delimiter ' ' CSV quote '"';


for Darren:

create table occupyla_int as ((select m1.from_user_row_id as from_user, m2.from_user_row_id as to_user, m1.parent_message_row_id as post_id from occupy_LA as m1 JOIN occupy_LA as m2 ON m1.parent_message_row_id = m2.row_id )
UNION ( select m.from_user_row_id, l.who_user_row_id, m.parent_message_row_id from occupy_LA as m JOIN likedby as l ON m.row_id = l.what_message_row_id )
UNION ( select t.user_row_id, m.from_user_row_id, m.parent_message_row_id from occupy_LA as m JOIN tag as t ON m.row_id = t.message_row_id ));
\copy (select * from occupyla_int) to 'occupyla_int.txt' with delimiter ' ' CSV quote '"';


Searching:
create table keyword_post_link as (select k_p.*, l.address  from keyword_post as k_p JOIN (select message_row_id, address from link where type = 'ACTION' and name = 'Comment') as l ON k_p.post_row_id = l.message_row_id);
select post_row_id, freq, address from keyword_post_link as k_p_l JOIN (select row_id from keyword where word ~ 'davis') as t ON k_p_l.keyword_row_id = t.row_id order by freq desc;
shares,likes,comments
create table search_temp as (select s.*, (select f.name from fb_user as f where f.row_id = m.fb_wall_row_id), m.created_time from search as s JOIN message as m ON s.post_row_id = m.row_id);
alter table search rename to search_old;
alter table search_temp rename to search;
create index search_keyword_row_id_idx on search using btree (keyword_row_id);
create index search_post_row_id_idx on search using btree (post_row_id);

For Teng,
\copy (select id, (select f1.id from fb_user as f1 where f1.row_id = l.who_user_row_id) as likedby_who_userID, (select f.id from fb_user as f where f.row_id = m.from_user_row_id) as likeToWho from message as m JOIN likedby as l ON m.row_id = l.what_message_row_id where fb_wall_row_id = 49) to 'occupy_ws.txt' with delimiter ',' CSV quote '"';
\copy (select id, (select f1.id from fb_user as f1 where f1.row_id = l.who_user_row_id) as likedby_who_userID, (select f.id from fb_user as f where f.row_id = m.from_user_row_id) as likeToWho from message as m JOIN likedby as l ON m.row_id = l.what_message_row_id where fb_wall_row_id = 2) to 'occupy_tog.txt' with delimiter ',' CSV quote '"';
\copy (select id, (select f1.id from fb_user as f1 where f1.row_id = l.who_user_row_id) as likedby_who_userID, (select f.id from fb_user as f where f.row_id = m.from_user_row_id) as likeToWho from message as m JOIN likedby as l ON m.row_id = l.what_message_row_id where fb_wall_row_id = 18560) to 'fox_news.txt' with delimiter ',' CSV quote '"';
\copy (select id, (select f1.id from fb_user as f1 where f1.row_id = l.who_user_row_id) as likedby_who_userID, (select f.id from fb_user as f where f.row_id = m.from_user_row_id) as likeToWho from message as m JOIN likedby as l ON m.row_id = l.what_message_row_id where fb_wall_row_id = 31132) to 'cnn.txt' with delimiter ',' CSV quote '"';

bug fixing:
create table count_bug (
message_row_id BIGINT not null,
likes_count int,
comments_count int,
PRIMARY KEY (message_row_id)
); 
\COPY count_bug(post_row_id, likes_count, comments_count) from '/home/rezaur/Documents/count.csv' with delimiter ',' CSV quote '"';
create index count_bug_message_row_id_idx on count_bug using btree (message_row_id);

create table message_temp as (select m.*, c.likes_count, c.comments_count from message as m LEFT OUTER JOIN count_bug as c ON message.row_id = c.message_row_id);
alter table message rename to message_no_lc_count;
alter table message_temp rename to message;
alter table message add CONSTRAINT message_pkey PRIMARY KEY (row_id);
alter table message add CONSTRAINT message_id_key UNIQUE(id);
alter table message add CONSTRAINT message_fb_wall_row_id_fkey FOREIGN KEY (fb_wall_row_id) REFERENCES fb_user(row_id) ON UPDATE CASCADE ON DELETE RESTRICT;
alter table message add CONSTRAINT message_from_user_row_id_fkey FOREIGN KEY (from_user_row_id) REFERENCES fb_user(row_id) ON UPDATE CASCADE ON DELETE RESTRICT;
alter table message add CONSTRAINT message_parent_message_row_id_fkey FOREIGN KEY (parent_message_row_id) REFERENCES message(row_id) ON UPDATE CASCADE ON DELETE RESTRICT;

