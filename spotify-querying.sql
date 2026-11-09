-- create table
DROP TABLE IF EXISTS spotify;
CREATE TABLE spotify (
    artist VARCHAR(255),
    track VARCHAR(255),
    album VARCHAR(255),
    album_type VARCHAR(50),
    danceability FLOAT,
    energy FLOAT,
    loudness FLOAT,
    speechiness FLOAT,
    acousticness FLOAT,
    instrumentalness FLOAT,
    liveness FLOAT,
    valence FLOAT,
    tempo FLOAT,
    duration_min FLOAT,
    title VARCHAR(255),
    channel VARCHAR(255),
    views FLOAT,
    likes BIGINT,
    comments BIGINT,
    licensed BOOLEAN,
    official_video BOOLEAN,
    stream BIGINT,
    energy_liveness FLOAT,
    most_playedon VARCHAR(50)
);


-- EDA

select count(*) from spotify;
select count(distinct album) from spotify;


select * from spotify
where duration_min = 0;

delete from spotify 
where duration_min = 0;


select distinct most_playedon from spotify;


/*
--------------------------------
-- Data Analysis - Easy Category
--------------------------------

1.Retrieve the names of all tracks that have more than 1 billion streams.
2.List all albums along with their respective artists.
3.Get the total number of comments for tracks where licensed = TRUE.
4.Find all tracks that belong to the album type single.
5.Count the total number of tracks by each artist.

*/

-- Q1.Retrieve the names of all tracks that have more than 1 billion streams.
select track from spotify 
where stream > 1000000000;

-- Q2.List all albums along with their respective artists.
select 
distinct album,
artist
from spotify;


-- Q3.Get the total number of comments for tracks where licensed = TRUE.
select
   sum(comments) as total_comments
from spotify
where licensed = true;

-- Q4.Find all tracks that belong to the album type single
select
   track
from spotify
where album_type = 'single';

-- Q5.Count the total number of tracks by each artist.
select
   artist,
   count(track) as total_tracks
from spotify
group by artist
order by total_tracks desc;

/*
-----------------
-- Medium level
-----------------
1.Calculate the average danceability of tracks in each album.
2.Find the top 5 tracks with the highest energy values.
3.List all tracks along with their views and likes where official_video = TRUE.
4.For each album, calculate the total views of all associated tracks.
5.Retrieve the track names that have been streamed on Spotify more than YouTube.
*/

-- Q1.Calculate the average danceability of tracks in each album.
select 
   album,
   avg(danceability) as average_danceability
from spotify
group by album
order by average_danceability desc;

--Q2.Find the top 5 tracks with the highest energy values.
select 
    track,
    max(energy) as maximum_energy
from spotify
group by 1
order by 2 desc
limit 5;

--Q3.List all tracks along with their views and likes where official_video = TRUE.
select 
   track,
   sum(views) as total_views,
   sum(likes) as total_likes
from spotify
where official_video = true
group by 1
order by 2 desc;

--Q4.For each album, calculate the total views of all associated tracks.
select 
    album,
    track,
    sum(views) as total_views
from spotify
group by 1,2
order by 3 desc;

--Q5.Retrieve the track names that have been streamed on Spotify more than YouTube.
select * from 
(select 
     track,
     coalesce(sum(case when most_playedon = 'Youtube' then stream end),0) as streamed_on_youtube,
     coalesce(sum(case when most_playedon = 'Spotify' then stream end),0) as streamed_on_spotify
from spotify
group by 1
) as t1
where 
   streamed_on_spotify > streamed_on_youtube
and 
   streamed_on_youtube <> 0;


/*
-------------------------
--Advanced Problems
-------------------------
1.Find the top 3 most-viewed tracks for each artist using window functions.
2.Write a query to find tracks where the liveness score is above the average.
3.Use a WITH clause to calculate the difference between the highest and lowest energy values for tracks in each album.
4.Find tracks where the energy-to-liveness ratio is greater than 1.2.
5.Calculate the cumulative sum of likes for tracks ordered by the number of views, using window functions.

*/

-- Q1.Find the top 3 most-viewed tracks for each artist using window functions.
--Steps:
--each artist and total view for each track
--track with the highest view for each artist (we need top 3)
--we will use dense rank window function
--to filter we will use cte and filter rank <=3

with ranking_artist
as (
select
    artist,
    track,
    sum(views) as total_view,
    dense_rank() over(
               partition by artist
               order by sum(views) desc
               ) as rank
from spotify
group by 1,2
order by 1,3 desc
)

select * from ranking_artist
where rank <= 3

-- Q2.Write a query to find tracks where the liveness score is above the average.
-- We use subquery
select 
   track 
from spotify
where liveness >
(
select
   avg(liveness)   -- 0.1936720
from spotify
);


-- Q3.Use a WITH clause to calculate the difference between the 
-- highest and lowest energy values for tracks in each album.

with cte
as (
select
   album,
   max(energy) as highest_energy,
   min(energy) as lowest_energy
from spotify
group by 1
)
select
     album,
	 highest_energy - lowest_energy as energy_difference
from cte
order by 2 desc;







