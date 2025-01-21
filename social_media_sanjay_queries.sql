
--     1.	Are there any tables with duplicate or missing null values? If so, how would you handle them?
show databases;
use ig_clone;
select count(*) from comments
where id is null or comment_text is null or user_id is null or photo_id is null or created_at is null;
select * from comments
group  by 1,2,3,4,5 
having count(*) >1;
show tables;
select count(*) from likes
where user_id is null or photo_id is null or created_at is null;
select * from likes
group by 1,2,3
having count(*) >1 ;
select count(*)  from follows
where follower_id is  null or followee_id is null or created_at is null;
select * from follows
group by 1,2,3
having count(*) >1;

select count(*) from photo_tags
where photo_id is null or tag_id is null;
select * from photo_tags
group by 1,2
having count(*) >1 ;

select count(*) from tags
where id is null or tag_name is null or created_at is null;

select * from tags
group by 1,2,3
having count(*) >1;

-- 2.	What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

select count(*) as users from  users;
select count(*) as photos from photos;
select count(*) as likes from likes;
select count(*) as tags from  tags;
select count(*) as photo_tags from photo_tags;
select count(*) as follows from follows;
select count(*) as comments from comments;

SELECT u.id AS user_id, u.username, 
COUNT(DISTINCT p.id) AS posts_count, 
CASE 
    WHEN COUNT(DISTINCT p.id) = 0 THEN 'Zero Posts' 
    WHEN COUNT(DISTINCT p.id) <= MAX(COUNT(DISTINCT p.id)) OVER() / 3 THEN 'Low Posts'
    WHEN COUNT(DISTINCT p.id) <= 2 * MAX(COUNT(DISTINCT p.id)) OVER() / 3 THEN 'Medium Posts'
    ELSE 'High Posts' 
END AS posts_segment,
COUNT(DISTINCT l.photo_id) AS likes_count, 
CASE 
    WHEN COUNT(DISTINCT l.photo_id) = 0 THEN 'Zero Likes'
    WHEN COUNT(DISTINCT l.photo_id) <= MAX(COUNT(DISTINCT l.photo_id)) OVER() / 3 THEN 'Low Likes'
    WHEN COUNT(DISTINCT l.photo_id) <= 2 * MAX(COUNT(DISTINCT l.photo_id)) OVER() / 3 THEN 'Medium Likes'
    ELSE 'High Likes' 
END AS likes_segment,
COUNT(DISTINCT c.id) AS comments_count,
CASE 
    WHEN COUNT(DISTINCT c.id) = 0 THEN 'Zero Comments'
    WHEN COUNT(DISTINCT c.id) <= MAX(COUNT(DISTINCT c.id)) OVER() / 3 THEN 'Low Comments'
    WHEN COUNT(DISTINCT c.id) <= 2 * MAX(COUNT(DISTINCT c.id)) OVER() / 3 THEN 'Medium Comments'
    ELSE 'High Comments' 
END AS comments_segment
FROM users u 
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY 1, 2;


-- 3.	Calculate the average number of tags per post (photo_tags and photos tables).

select round(avg(tag_count),0) average_tag_per_post from (
select count(pt.tag_id) as tag_count from photo_tags  pt 
join photos p on p.id= pt.photo_id 
group by p.id) p;

-- 4.	Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
WITH engagement_rates AS (
    SELECT 
        u.id,
        u.username,
        COUNT(l.photo_id) AS count_of_likes,
        COUNT(c.comment_text) AS count_of_comments  -- Renamed this column
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY u.id, u.username
)
SELECT 
    id,
    username,
    count_of_likes,
    count_of_comments,
    DENSE_RANK() OVER (ORDER BY count_of_likes DESC) AS ranks
FROM engagement_rates;

-- 5.	Which users have the highest number of followers and followings?
select 
u.username,
f.followee_id as user_id,
count(*) as followers_count
from 
follows f
join 
users u on f.followee_id = u.id
group by 
f.followee_id
having count(*) = (select max(follower_count) from (select count(*) as follower_count
from follows
group by followee_id
) as e
);

select 
u.username,
f.follower_id as user_id,
count(*) as followings_count
from 
follows f
join 
users u on f.follower_id = u.id
group by 
f.follower_id
having count(*) = (select max(following_count) from (select count(*) as following_count
from follows
group by follower_id
) as e
);

-- 6.	Calculate the average engagement rate (likes, comments) per post for each user.
select sum(likes_count + comments_count) / count(p.id) as average_engagment_rate_per_post
from users u join photos p
on p.user_id = u.id
left join (select photo_id , count(*) as likes_count from likes
group by photo_id) l on p.id = l.photo_id
left join (select photo_id , count(*) as comments_count from comments
group by photo_id) c on p.id = c.photo_id;

-- 7.	Get the list of users who have never liked any post (users and likes tables)

select u.username ,
u.id as user_id from users u left join likes l
on u.id =l.user_id
where l.user_id is null;

-- 8.	How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns? 
SELECT id AS user_id, tag_name, tags_count 
FROM (
	SELECT u.id, t.tag_name, COUNT(t.tag_name) AS tags_count,
	DENSE_RANK() OVER(PARTITION BY tag_name ORDER BY COUNT(t.tag_name) DESC) AS ranking
	FROM users u
	JOIN photos p on u.id = p.user_id
	JOIN photo_tags pt on p.id = pt.photo_id
	JOIN tags t on pt.tag_id = t.id
	GROUP BY 1, 2
) AS dt
WHERE ranking = 1;

-- 9.	Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? How can this information guide content creation and curation strategies? 
SELECT p.id AS photo_id, p.image_url AS photo_url, COUNT(DISTINCT l.user_id) AS likes_count, COUNT(DISTINCT c.id) AS comments_count
FROM photos p
LEFT JOIN likes l on p.id = l.photo_id
LEFT JOIN comments c on p.id = c.photo_id
GROUP BY 1
ORDER BY 3 DESC;

--  10.	Calculate the total number of likes, comments, and photo tags for each user.
SELECT 
    u.username,
    COALESCE(SUM(l.likes_count), 0) AS total_likes,
    COALESCE(SUM(c.comment_count), 0) AS total_comments,
    COALESCE(SUM(pt.tag_count), 0) AS total_photo_tags
FROM 
    users u
LEFT JOIN 
    photos p ON u.id = p.user_id
LEFT JOIN 
    (SELECT 
         photo_id, 
         COUNT(*) AS likes_count 
     FROM 
         likes 
     GROUP BY 
         photo_id) l ON p.id = l.photo_id
LEFT JOIN 
    (SELECT 
         photo_id, 
         COUNT(*) AS comment_count 
     FROM 
         comments 
     GROUP BY 
         photo_id) c ON p.id = c.photo_id
LEFT JOIN 
    (SELECT 
         photo_id, 
         COUNT(*) AS tag_count 
     FROM 
         photo_tags 
     GROUP BY 
         photo_id) pt ON p.id = pt.photo_id
GROUP BY 
    u.id, u.username
ORDER BY 
    u.username;
    
-- 11.	Rank users based on their total engagement (likes, comments, shares) over a month.
WITH engagement_data AS (
    SELECT 
        u.username,
        COUNT(DISTINCT l.photo_id) AS total_likes,
        COUNT(DISTINCT c.id) AS total_comments,
        COUNT(DISTINCT f.follower_id) AS total_shares,
        COUNT(DISTINCT l.photo_id) + 
        COUNT(DISTINCT c.id) + 
        COUNT(DISTINCT f.follower_id) AS total_engagement
    FROM 
        users u
    LEFT JOIN 
        photos p ON u.id = p.user_id
    LEFT JOIN 
        likes l ON p.id = l.photo_id
    LEFT JOIN 
        comments c ON p.id = c.photo_id
    LEFT JOIN 
        follows f ON p.user_id = f.followee_id
    GROUP BY 
        u.id, u.username
)
SELECT 
    username, 
    total_likes, 
    total_comments, 
    total_shares, 
    total_engagement,
    DENSE_RANK() OVER (ORDER BY total_engagement DESC) AS engagement_rank
FROM 
    engagement_data
ORDER BY 
    engagement_rank;

-- 12.	Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.
 with tag_avg_likes as  (
 select t.tag_name as hashtag, 
 avg(count_likes) as avg_likes
 from (select p.id as photo_id , 
 count(l.user_id) as count_likes
 from photos p left join likes l on p.id = l.photo_id
 group by p.id) photo_likes
 join photo_tags pt on photo_likes.photo_id = pt.photo_id
 join tags t on pt.tag_id = t.id
 group by t.tag_name
 )
 select hashtag,
 avg_likes
 from tag_avg_likes
 where avg_likes = (select max(avg_likes) from tag_avg_likes);

-- 13.	Retrieve the users who have started following someone after being followed by that person

SELECT 
    f1.follower_id AS followed_user_id,
    u1.username AS followed_user,
    f1.followee_id AS started_following_user_id,
    u2.username AS starting_following_user
FROM 
    follows f1
JOIN 
    follows f2 
    ON f1.follower_id = f2.followee_id AND f1.followee_id = f2.follower_id
JOIN 
    users u1 
    ON f1.follower_id = u1.id
JOIN 
    users u2 
    ON f1.followee_id = u2.id
WHERE 
    f1.created_at >= f2.created_at;
    
-- subjective qeustions :
-- 1.	Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?

WITH cte AS (
    SELECT u.id AS user_id, 
           u.username, 
           COUNT(DISTINCT p.id) AS posts_count, 
           COUNT(DISTINCT l.photo_id) AS likes_count, 
           COUNT(DISTINCT c.id) AS comments_count,
           COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) AS user_engagement, 
           DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) DESC) AS drank
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY 1, 2
)
SELECT user_id, username, posts_count, likes_count, comments_count, user_engagement
FROM cte 
WHERE drank BETWEEN 1 AND 5 AND posts_count > 0;
    
-- 2.	For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

WITH cte AS (
    SELECT u.id AS user_id, 
           u.username, 
           COUNT(DISTINCT p.id) AS posts_count, 
           COUNT(DISTINCT l.photo_id) AS likes_count, 
           COUNT(DISTINCT c.id) AS comments_count,
           COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) AS user_engagement, 
           DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) AS drank
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY 1, 2
)
SELECT user_id, username, posts_count, likes_count, comments_count, user_engagement
FROM cte 
WHERE drank BETWEEN 1 AND 10
ORDER BY 1;


--  3.	Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?

WITH count_likes AS (
    SELECT t.tag_name, COUNT(l.user_id) AS likes_count
    FROM tags t
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN likes l ON pt.photo_id = l.photo_id
    GROUP BY 1
),
count_posts AS (
    SELECT t.tag_name, COUNT(p.id) AS posts_count
    FROM tags t 
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN photos p ON pt.photo_id = p.id
    GROUP BY 1
), 
count_comments AS (
    SELECT t.tag_name, COUNT(c.id) AS comments_count
    FROM tags t 
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN comments c ON pt.photo_id = c.photo_id
    GROUP BY 1
)
SELECT cl.tag_name, 
       cl.likes_count + cp.posts_count + cc.comments_count AS engagement,
       ROUND((cl.likes_count + cp.posts_count + cc.comments_count) * 100 / SUM(cl.likes_count + cp.posts_count + cc.comments_count) OVER(), 2) AS engagement_rate
FROM count_likes cl
JOIN count_posts cp ON cl.tag_name = cp.tag_name
JOIN count_comments cc ON cl.tag_name = cc.tag_name
ORDER BY 2 DESC 
LIMIT 5;


-- 4.	Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? How can these insights inform targeted marketing campaigns?

-- for peak postinng time
SELECT
    WEEKDAY(u.created_at) AS day_of_week, 
    EXTRACT(HOUR FROM u.created_at) AS hour_of_day,       
    COUNT(DISTINCT p.id) AS total_photos_posted,         
    COUNT(DISTINCT l.user_id) AS total_likes_received,     
    COUNT(DISTINCT c.id) AS total_comments_made         
FROM users u 
LEFT JOIN photos p
	ON u.id = p.user_id
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
WHERE EXTRACT(HOUR FROM p.created_dat) is not null 
GROUP BY
    day_of_week,
    hour_of_day
ORDER BY
    day_of_week,
    hour_of_day;
SELECT
    WEEKDAY(p.created_dat) AS day_of_week, 
    EXTRACT(HOUR FROM p.created_dat) AS hour_of_day,       
    COUNT(DISTINCT p.id) AS total_photos_posted,         
    COUNT(DISTINCT l.user_id) AS total_likes_received,     
    COUNT(DISTINCT c.id) AS total_comments_made         
FROM photos p
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
GROUP BY
    day_of_week,
    hour_of_day
ORDER BY
    day_of_week,
    hour_of_day;
 -- 5.	Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers?
 
WITH cte AS (
    SELECT username, engagement_rate, follower_count,
           (engagement_rate * 0.6 + follower_count * 0.4) AS weighted_score
    FROM ( 
        SELECT u.id AS user_id, u.username, 
               (COALESCE(posts_count, 0) + COALESCE(likes_count, 0) + COALESCE(comments_count, 0)) * 100 / 
               SUM((COALESCE(posts_count, 0) + COALESCE(likes_count, 0) + COALESCE(comments_count, 0))) OVER() AS engagement_rate,
               follower_count
        FROM users u
        LEFT JOIN (
            SELECT user_id, COUNT(*) AS posts_count
            FROM photos
            GROUP BY user_id
        ) p ON u.id = p.user_id
        LEFT JOIN (
            SELECT user_id, COUNT(DISTINCT photo_id) AS likes_count
            FROM likes
            GROUP BY user_id
        ) l ON u.id = l.user_id
        LEFT JOIN (
            SELECT user_id, COUNT(*) AS comments_count
            FROM comments
            GROUP BY user_id
        ) c ON u.id = c.user_id
        LEFT JOIN (
            SELECT followee_id, COUNT(DISTINCT follower_id) AS follower_count
            FROM follows
            GROUP BY followee_id
        ) f2 ON u.id = f2.followee_id
    ) dt
) 
SELECT username, engagement_rate, follower_count, weighted_score
FROM cte 
WHERE follower_count = (select max(follower_count) from cte) and engagement_rate > 0
ORDER BY weighted_score DESC;

-- 6.	Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?

WITH user_engagement AS (
    SELECT 
        u.id AS user_id, 
        u.username, 
        COALESCE(p.engagement, 0) + COALESCE(l.engagement, 0) + COALESCE(c.engagement, 0) AS engagement,
        COALESCE(t.tag_count, 0) AS tag_count
    FROM 
        users u
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT id) AS engagement
        FROM photos
        GROUP BY user_id
    ) p ON u.id = p.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT photo_id) AS engagement
        FROM likes
        GROUP BY user_id
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT id) AS engagement
        FROM comments
        GROUP BY user_id
    ) c ON u.id = c.user_id
    LEFT JOIN (
		SELECT u.id AS user_id, 
        COUNT(DISTINCT t.tag_name) AS tag_count
        FROM
        users u
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    LEFT JOIN tags t ON pt.tag_id = t.id
    GROUP BY u.id
    ) t ON u.id = t.user_id
),
global_max AS (
    SELECT 
        MAX(engagement) AS max_engagement, 
        MAX(tag_count) AS max_tag_count
    FROM user_engagement
),
user_tags AS (
    SELECT
        u.id AS user_id,
        group_concat(t.tag_name) AS tags
    FROM
        users u
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    LEFT JOIN tags t ON pt.tag_id = t.id
    GROUP BY u.id
),
user_segments AS (
    SELECT
        e.user_id,
        e.username,
        e.engagement,
        e.tag_count,
        t.tags,
        CASE
            WHEN e.engagement < gm.max_engagement / 3 AND e.tag_count < gm.max_tag_count / 3 THEN 'Low Engagement'
            WHEN e.engagement < 2 * gm.max_engagement / 3 AND e.tag_count < 2 * gm.max_tag_count / 3 THEN 'Moderate Engagement'
            ELSE 'High Engagement'
        END AS engagement_segment
    FROM user_engagement e
    LEFT JOIN user_tags t ON e.user_id = t.user_id
    CROSS JOIN global_max gm  -- Cross join to ensure you can use the global maximums
    GROUP BY e.user_id, e.username, e.engagement, e.tag_count, t.tags, gm.max_engagement, gm.max_tag_count
)
SELECT *
FROM user_segments
WHERE tag_count > 0 AND tags IS NOT NULL and engagement_segment in ('High Engagement', 'Low Engagement')
ORDER BY engagement_segment, engagement DESC;
 

#Subjective Answer-10
UPDATE User_Interactions
SET Engagement_Type = ‘Heat’
WHERE Engagement_Type = ‘Like’;
 

 


