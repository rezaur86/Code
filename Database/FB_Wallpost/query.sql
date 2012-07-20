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

create table post_info as (
select parent_message_row_id as post_row_id, array_to_string(array_agg(text), ', ') as info from (
	select parent_message_row_id, text 


message where parent_message_row_id is not null group by parent_message_row_id;
