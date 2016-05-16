--
-- Created: 2015.09.14
-- Copyright: Steven E. Pav, 2015
-- Author: Steven E. Pav <shabbychef@gmail.com>
-- Comments: Steven E. Pav

-- .header 1
-- .separator |

-- remove columns we do not need. Will simplify, I think, the removal of
-- rows later. c.f.
-- http://stackoverflow.com/a/5987838/164611
BEGIN TRANSACTION;
-- keep only movies:
DELETE FROM title WHERE kind_id IN (SELECT id FROM kind_type WHERE NOT kind='movie');
-- drop some columns (including kind_id)
CREATE TEMPORARY TABLE title_backup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    imdb_index VARCHAR(12),
    production_year INT,
    imdb_id INT,
    md5sum VARCHAR(32)
);
INSERT INTO title_backup SELECT id,title,imdb_index,production_year,imdb_id,md5sum FROM title;
DROP TABLE title;
CREATE TABLE title (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    imdb_index VARCHAR(12),
    production_year INT,
    imdb_id INT,
    md5sum VARCHAR(32)
);
INSERT INTO title SELECT id,title,imdb_index,production_year,imdb_id,md5sum FROM title_backup;
DROP TABLE title_backup;
COMMIT;

BEGIN TRANSACTION;
-- keep only movies:
DELETE FROM aka_title WHERE kind_id IN (SELECT id FROM kind_type WHERE NOT kind='movie');
-- drop some columns (including kind_id)
CREATE TEMPORARY TABLE aka_title_backup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
		movie_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    imdb_index VARCHAR(12),
    production_year INT,
		note TEXT,
    md5sum VARCHAR(32)
);
INSERT INTO aka_title_backup SELECT id,movie_id,title,imdb_index,production_year,note,md5sum FROM aka_title;
DROP TABLE aka_title;
CREATE TABLE aka_title (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    movie_id INT NOT NULL,
    title TEXT NOT NULL,
    imdb_index VARCHAR(12),
    production_year INT,
    note TEXT,
    md5sum VARCHAR(32)
);
CREATE INDEX aka_title_idx_movieid ON aka_title (movie_id);
--CREATE INDEX aka_title_idx_md5 ON aka_title (md5sum);
INSERT INTO aka_title SELECT id,movie_id,title,imdb_index,production_year,note,md5sum FROM aka_title_backup;
DROP TABLE aka_title_backup;
COMMIT;

-- prune a fresh imdb dump to remove porn, TV shows, video games, 
-- old titles, marginal titles, future releases, etc.
BEGIN TRANSACTION;

-- remove porn:
DELETE FROM title WHERE id in (SELECT movie_id FROM movie_info WHERE info_type_id=3 AND info='Adult');
-- remove really old titles
DELETE FROM title WHERE production_year < 1930;

-- * Thu Feb 04 2016 10:07:13 AM Steven E. Pav shabbychef@gmail.com
-- A filter to get rid of bad titles:
-- Anything with a NULL production_year is getting the ax.
-- These tend to be titles that have not been released yet, and we will
-- get them eventually.
DELETE FROM title WHERE production_year IS NULL;

-- * Wed Dec 02 2015 03:47:07 PM Steven E. Pav shabbychef@gmail.com
-- OK, I am lowering the boom here. If you are a movie
-- with production year from 3 years ago or more (i.e. 2012 and prior
-- as I write this in December 2015), and you have fewer than 50 votes
-- on IMDb, then you are total crap, and I am throwing you away.
-- That cuts ~ 462K titles from ~ 741K titles total. 
-- And those are all total crap titles.
DELETE FROM title WHERE 
production_year <= CAST(strftime('%Y', datetime('now')) AS UNSIGNED INTEGER) - 3 AND 
id NOT IN 
(SELECT movie_id FROM 
(SELECT movie_id,CAST(info AS UNSIGNED INTEGER) AS NVOTES FROM movie_info_idx WHERE info_type_id IN (SELECT id FROM info_type WHERE info='votes') AND NVOTES >= 50));

COMMIT;

-- prune again based on missing movies
BEGIN TRANSACTION;
DELETE FROM aka_title WHERE movie_id NOT IN (SELECT id FROM title);
COMMIT;
BEGIN TRANSACTION;
DELETE FROM movie_info WHERE movie_id NOT IN (SELECT id FROM title);
COMMIT;
BEGIN TRANSACTION;
DELETE FROM movie_info_idx WHERE movie_id NOT IN (SELECT id FROM title);
COMMIT;
BEGIN TRANSACTION;
DELETE FROM movie_keyword WHERE movie_id NOT IN (SELECT id FROM title);
COMMIT;
BEGIN TRANSACTION;
DELETE FROM cast_info WHERE movie_id NOT IN (SELECT id from title);
COMMIT;
BEGIN TRANSACTION;
DELETE FROM movie_companies WHERE movie_id NOT IN (SELECT id from title);
COMMIT;

-- delete stranded (likely porn) actors:
BEGIN TRANSACTION;
DELETE FROM person_info WHERE person_id NOT IN (SELECT person_id from cast_info);

DELETE FROM name WHERE id NOT IN (SELECT DISTINCT(person_id) FROM cast_info);

DELETE FROM aka_name WHERE person_id NOT IN (SELECT DISTINCT(id) FROM name);
COMMIT;

-- delete stranded (likely porn) keywords;
BEGIN TRANSACTION;
DELETE FROM keyword WHERE id NOT IN (SELECT keyword_id FROM movie_keyword);

-- 2FIX: remove stranded companies?
DELETE FROM company_name WHERE id NOT IN (SELECT DISTINCT(company_id) FROM movie_companies);
COMMIT;

-- finally, create some missing indices
CREATE INDEX title_idx_title ON title (title);
CREATE INDEX title_idx_imdb_id ON title (imdb_id);
-- CREATE INDEX aka_title_idx_title ON aka_title (title);

-- for vim modeline: (do not edit)
-- vim:ts=2:sw=2:tw=79:fdm=indent:cms=--%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
