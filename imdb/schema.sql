#
# Created: 2015.09.16
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

# nb. to have an index'able column in innoDB, the maximum bytes is 767.

# 2FIX: b/c we are in utf8b4 the maximum key length is 249 characters, which
# translates to 1000 bytes. bleah.

DROP TABLE IF EXISTS name CASCADE;
CREATE TABLE `name` (
	`person_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`name` VARCHAR(128),
	`imdb_index` VARCHAR(12),
	`nmid` INT(7) UNSIGNED NULL,
	`gender` VARCHAR(1),
	`dob` DATE DEFAULT NULL,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `name_idx_name` (`name`),
	INDEX `name_idx_nmid` (`nmid`),
	INDEX `name_idx_dob` (`dob`),
	INDEX `name_idx_md5` (`md5sum`),
	UNIQUE KEY `name_uni_row` (`name`,`imdb_index`)
) ENGINE=MyISAM;

# need this sometimes for director aliases
DROP TABLE IF EXISTS `aka_name` CASCADE;
CREATE TABLE `aka_name` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`person_id` INT NOT NULL,
	`name` VARCHAR(127) NOT NULL,
	`imdb_index` VARCHAR(12),
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `aka_name_person_id` (`person_id`),
	INDEX `aka_name_name` (`name`),
	INDEX `aka_name_imdb_index` (`imdb_index`)
);

# possibly put uniqueness constraint in here.
DROP TABLE IF EXISTS char_name CASCADE;
CREATE TABLE `char_name` (
	`char_name_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`name` VARCHAR(249) NOT NULL,
	`imdb_index` VARCHAR(12),
	`chid` INT(7) UNSIGNED NULL,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `char_name_idx_name` (`name`),
	INDEX `char_name_idx_md5` (`md5sum`)
) ENGINE=MyISAM;

# possibly put uniqueness constraint in here.
DROP TABLE IF EXISTS company_name CASCADE;
CREATE TABLE `company_name` (
	`company_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`name` VARCHAR(249) NOT NULL,
	`country_code` VARCHAR(255),
	`coid` INT(7) UNSIGNED NULL,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `company_name_idx_name` (`name`),
	INDEX `company_name_idx_md5` (`md5sum`)
) ENGINE=MyISAM;

# start here..
DROP TABLE IF EXISTS title CASCADE;
CREATE TABLE `title` (
	`movie_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`title` VARCHAR(247) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
	`imdb_index` VARCHAR(12),
	`production_year` INT(4) UNSIGNED,
	`ttid` INT(7) UNSIGNED NULL,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `title_idx_title` (`title`),
	INDEX `title_idx_ttid` (`ttid`),
	INDEX `title_idx_year` (`production_year`),
	INDEX `title_idx_md5` (`md5sum`),
	UNIQUE KEY `title_uni_row` (`title`(200), `imdb_index`(11), `production_year`),
	CHECK(production_year >= 1870 AND production_year <= 2050)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS aka_title CASCADE;
CREATE TABLE `aka_title` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INTEGER UNSIGNED NOT NULL,
	`title` VARCHAR(249) NOT NULL,
	`imdb_index` VARCHAR(12),
	`production_year` INT(4) UNSIGNED,
	`note` TEXT,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin,
	INDEX `aka_title_idx_movie_id` (`movie_id`),
	INDEX `aka_title_idx_title` (`title`),
	INDEX `aka_title_idx_production_year` (`production_year`),
	CHECK(production_year >= 1870 AND production_year <= 2050)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS company_type CASCADE;
CREATE TABLE `company_type` (
	`company_type_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`kind` VARCHAR(32) NOT NULL UNIQUE,
	INDEX `company_type_idx_kind` (`kind`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS role_type CASCADE;
CREATE TABLE `role_type` (
	`role_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`role` VARCHAR(32) NOT NULL UNIQUE,
	INDEX `role_type_idx_kind` (`role`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS cast_info CASCADE;
CREATE TABLE `cast_info` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`person_id` INT UNSIGNED NOT NULL,
	`movie_id` INT UNSIGNED NOT NULL,
	`char_name_id` INT UNSIGNED,
	`note` TEXT,
	`nr_order` INT,
	`role_id` INT UNSIGNED NOT NULL,
	INDEX `cast_info_idx_pid` (`person_id`),
	INDEX `cast_info_idx_mid` (`movie_id`),
	INDEX `cast_info_idx_cid` (`char_name_id`),
	INDEX `cast_info_idx_rid` (`role_id`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS info_type CASCADE;
CREATE TABLE `info_type` (
	`info_type_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`info` VARCHAR(32) NOT NULL UNIQUE,
	INDEX `info_type_idx_kind` (`info`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS keyword CASCADE;
CREATE TABLE `keyword` (
	`keyword_id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`keyword` VARCHAR(249) NOT NULL UNIQUE,
	INDEX `keyword_idx_keyword` (`keyword`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS movie_keyword CASCADE;
CREATE TABLE `movie_keyword` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`keyword_id` INT UNSIGNED NOT NULL,
	INDEX `movie_keyword_idx_mid` (`movie_id`),
	INDEX `movie_keyword_idx_keywordid` (`keyword_id`)
) ENGINE=MyISAM;

# this seems to be for following type of info:
# id|info
# 1|runtimes
# 3|genres
# 9|taglines
# 16|release dates
# 97|mpaa
# 98|plot
# 102|production dates
# 103|copyright holder
# 104|filming dates
# 105|budget
# 106|weekend gross
# 107|gross
# 108|opening weekend
# 109|rentals
# 110|admissions
DROP TABLE IF EXISTS movie_info CASCADE;
CREATE TABLE `movie_info` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`info_type_id` INT UNSIGNED NOT NULL,
	`info` TEXT NOT NULL,
	`note` TEXT,
	INDEX `movie_info_idx_mid` (`movie_id`),
	INDEX `movie_info_idx_iid` (`info_type_id`)
) ENGINE=MyISAM;

# this seems to be for following type of info:
# id|info
# 99|votes distribution
# 100|votes
# 101|rating
# 112|top 250 rank
# 113|bottom 10 rank
# the 'votes distribution' is the most important, rather.
DROP TABLE IF EXISTS movie_info_idx CASCADE;
CREATE TABLE `movie_info_idx` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`info_type_id` INT UNSIGNED NOT NULL,
	`info` VARCHAR(15) NOT NULL,
	`note` TEXT,
	INDEX `movie_info_idx_idx_mid` (`movie_id`),
	INDEX `movie_info_idx_idx_infotypeid` (`info_type_id`),
	INDEX `movie_info_idx_idx_info` (`info`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS person_info CASCADE;
CREATE TABLE `person_info` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`person_id` INT UNSIGNED NOT NULL,
	`info_type_id` INT UNSIGNED NOT NULL,
	`info` TEXT NOT NULL,
	`note` TEXT,
	INDEX `person_info_idx_mid` (`person_id`),
	INDEX `person_info_idx_iid` (`info_type_id`)
) ENGINE=MyISAM;

# OK, the votes, rating, and votes distribution are locked up in *TEXT*. Fuck. That.
DROP TABLE IF EXISTS movie_votes CASCADE;
CREATE TABLE `movie_votes` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`updated_at` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
	`votes` INT UNSIGNED NOT NULL,
	`rating` DECIMAL(3,1) NOT NULL,
	`vote_mean` DECIMAL(4,2) NOT NULL,
	`vote_sd` DECIMAL(5,3),
	`vote_se` DECIMAL(6,4),
	`vote1` INT(2),
	`vote2` INT(2),
	`vote3` INT(2),
	`vote4` INT(2),
	`vote5` INT(2),
	`vote6` INT(2),
	`vote7` INT(2),
	`vote8` INT(2),
	`vote9` INT(2),
	`vote10` INT(2),
	`movie_id` INT UNSIGNED NOT NULL,
	INDEX `movie_votes_idx_votes` (`votes`),
	INDEX `movie_votes_idx_rating` (`rating`),
	INDEX `movie_votes_idx_vote_mean` (`vote_mean`),
	INDEX `movie_votes_idx_vote_sd` (`vote_sd`),
	INDEX `movie_votes_idx_vote_se` (`vote_se`),
	INDEX `movie_votes_idx_vote1` (`vote1`),
	INDEX `movie_votes_idx_vote2` (`vote2`),
	INDEX `movie_votes_idx_vote3` (`vote3`),
	INDEX `movie_votes_idx_vote4` (`vote4`),
	INDEX `movie_votes_idx_vote5` (`vote5`),
	INDEX `movie_votes_idx_vote6` (`vote6`),
	INDEX `movie_votes_idx_vote7` (`vote7`),
	INDEX `movie_votes_idx_vote8` (`vote8`),
	INDEX `movie_votes_idx_vote9` (`vote9`),
	INDEX `movie_votes_idx_vote10` (`vote10`),
	INDEX `movie_votes_idx_movie_id` (`movie_id`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS movie_companies CASCADE;
CREATE TABLE `movie_companies` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`company_id` INT UNSIGNED NOT NULL,
	`company_type_id` INT UNSIGNED NOT NULL,
	`note` TEXT,
	INDEX `movie_companies_idx_mid` (`movie_id`),
	INDEX `movie_companies_idx_cid` (`company_id`),
	INDEX `movie_companies_idx_ctid` (`company_type_id`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_budgets CASCADE;
CREATE TABLE `movie_budgets` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`units` VARCHAR(4) CHARACTER SET utf8 COLLATE utf8_unicode_ci,
	`amount` DECIMAL(12,2),
	INDEX `movie_budgets_idx_movie_id` (`movie_id`),
	INDEX `movie_budgets_idx_amount` (`amount`),
	INDEX `movie_budgets_idx_units` (`units`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_gross CASCADE;
CREATE TABLE `movie_gross` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`units` VARCHAR(4) CHARACTER SET utf8 COLLATE utf8_unicode_ci,
	`amount` DECIMAL(11,2) NOT NULL,
	`locale` VARCHAR(31),
	`reissue` BOOL,
	`end_date` DATE,
	INDEX `movie_gross_idx_movie_id` (`movie_id`),
	INDEX `movie_gross_idx_units` (`units`),
	INDEX `movie_gross_idx_amount` (`amount`),
	INDEX `movie_gross_idx_locale` (`locale`),
	INDEX `movie_gross_idx_end_date` (`end_date`)
) ENGINE=MyISAM;

# duplicated data, really
CREATE OR REPLACE VIEW `movie_US_gross` AS
	SELECT movie_id,MAX(amount) AS `gross_dollars`,MAX(COALESCE(end_date,CURDATE())) AS `last_report_date` FROM movie_gross WHERE units='$' AND locale='USA' GROUP BY movie_id;

# duplicated data, really
DROP TABLE IF EXISTS movie_opening_weekend CASCADE;
CREATE TABLE `movie_opening_weekend` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`units` VARCHAR(4) CHARACTER SET utf8 COLLATE utf8_unicode_ci,
	`amount` DECIMAL(11,2) NOT NULL,
	`locale` VARCHAR(31),
	`screens` INT(5),
	`end_date` DATE,
	INDEX `movie_opening_weekend_idx_movie_id` (`movie_id`),
	INDEX `movie_opening_weekend_idx_units` (`units`),
	INDEX `movie_opening_weekend_idx_amount` (`amount`),
	INDEX `movie_opening_weekend_idx_locale` (`locale`),
	INDEX `movie_opening_weekend_idx_screens` (`screens`),
	INDEX `movie_opening_weekend_idx_end_date` (`end_date`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_weekend_gross CASCADE;
CREATE TABLE `movie_weekend_gross` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`units` VARCHAR(4) CHARACTER SET utf8 COLLATE utf8_unicode_ci,
	`amount` DECIMAL(11,2) NOT NULL,
	`locale` VARCHAR(31),
	`screens` INT(5),
	`end_date` DATE,
	`days_open` INT(5),
	INDEX `movie_weekend_gross_idx_movie_id` (`movie_id`),
	INDEX `movie_weekend_gross_idx_units` (`units`),
	INDEX `movie_weekend_gross_idx_amount` (`amount`),
	INDEX `movie_weekend_gross_idx_locale` (`locale`),
	INDEX `movie_weekend_gross_idx_screens` (`screens`),
	INDEX `movie_weekend_gross_idx_end_date` (`end_date`),
	INDEX `movie_weekend_gross_idx_days_open` (`days_open`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_rentals CASCADE;
CREATE TABLE `movie_rentals` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`units` VARCHAR(4) CHARACTER SET utf8 COLLATE utf8_unicode_ci,
	`amount` DECIMAL(11,2) NOT NULL,
	`locale` VARCHAR(31),
	`estimated` BOOL,
	`ex_usa` BOOL,
	INDEX `movie_rentals_idx_movie_id` (`movie_id`),
	INDEX `movie_rentals_idx_units` (`units`),
	INDEX `movie_rentals_idx_amount` (`amount`),
	INDEX `movie_rentals_idx_locale` (`locale`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_admissions CASCADE;
CREATE TABLE `movie_admissions` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`amount` DECIMAL(11,2) NOT NULL,
	`locale` VARCHAR(31),
	`end_date` DATE,
	INDEX `movie_admissions_idx_movie_id` (`movie_id`),
	INDEX `movie_admissions_idx_amount` (`amount`),
	INDEX `movie_admissions_idx_locale` (`locale`),
	INDEX `movie_admissions_idx_end_date` (`end_date`)
) ENGINE=MyISAM;

# duplicated data, really
DROP TABLE IF EXISTS movie_release_dates CASCADE;
CREATE TABLE `movie_release_dates` (
	`id` INTEGER PRIMARY KEY AUTO_INCREMENT,
	`movie_id` INT UNSIGNED NOT NULL,
	`locale` VARCHAR(31),
	`date` DATE NOT NULL,
	`is_premiere` BOOL,
	`note` VARCHAR(63),
	INDEX `movie_release_dates_movie_id` (`movie_id`),
	INDEX `movie_release_dates_locale` (`locale`),
	INDEX `movie_release_dates_date` (`date`),
	INDEX `movie_release_dates_is_premiere` (`is_premiere`)
) ENGINE=MyISAM;

# first release view
# * Thu Jan 07 2016 11:03:49 AM Steven E. Pav shabbychef@gmail.com
# I changed this since 'is_premiere' is sparsely populated...
CREATE OR REPLACE VIEW `movie_first_US_release` AS
	SELECT movie_id,MIN(date) AS `date` FROM movie_release_dates WHERE locale='USA' GROUP BY movie_id;

# first release view
CREATE OR REPLACE VIEW `movie_premiere_US_release` AS
	SELECT movie_id,MIN(date) AS `date` FROM movie_release_dates WHERE locale='USA' AND is_premiere=1 GROUP BY movie_id;

# movie runtime view
# you want to create it as a single view, but mariadb does not like SELECT FROM
# in subclause of view definition.
CREATE OR REPLACE VIEW `movie_raw_runtimes` AS
  SELECT movie_id,CAST(REGEXP_REPLACE(info,'^(\\D+:\\s*)?(\\d+)\\s*$','\\2') AS UNSIGNED INT) as rt 
  FROM movie_info 
  WHERE info_type_id IN 
    (SELECT info_type_id FROM info_type WHERE info REGEXP 'runtimes');

CREATE OR REPLACE VIEW `movie_runtime` AS
  SELECT movie_id,AVG(rt) as runtime,MIN(rt) as minruntime,MAX(rt) as maxruntime,count(*) as nruntimes 
	FROM movie_raw_runtimes
	GROUP BY movie_id;

# votes per year view
# mysql was OK with this, but mariadb pukes:
#CREATE OR REPLACE VIEW `votes_per_year` AS
  #SELECT `movie_id` AS `movie_id`, COALESCE(`votes` / GREATEST(1.0, COALESCE(1.0 + YEAR(CURDATE()) - `production_year`, 1.0)), 0.0) AS `vpy`
  #FROM (SELECT zzz19.movie_id,zzz19.production_year,zzz20.votes FROM (SELECT `movie_id`, `production_year` FROM `title`) AS `zzz19`
  #LEFT JOIN 
  #(SELECT `movie_id`, `votes` FROM `movie_votes`) AS `zzz20`
  #ON (zzz19.movie_id = zzz20.movie_id)) AS `zzz21`;

# mariadb is OK with this:
CREATE OR REPLACE VIEW `votes_per_year` AS
  SELECT ttl.movie_id, COALESCE(mv.votes / GREATEST(1.0, COALESCE(1.0 + YEAR(CURDATE()) - ttl.production_year, 1.0)), 0.0) AS `vpy`
  FROM `title` AS `ttl`
  LEFT JOIN
  movie_votes AS `mv`
  ON ttl.movie_id=mv.movie_id;

# note that the top movies in the 'votes per year' ordering tend to be very
# recent. there should probably be a better way to evenly count votes..

# fill these in later:

DROP TABLE IF EXISTS title_link CASCADE;
CREATE TABLE `title_link` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE KEY,
	`ttid` INTEGER(7) UNSIGNED NOT NULL,
	INDEX `title_link_md5sum` (`md5sum`),
	INDEX `title_link_ttid` (`ttid`)
) ENGINE=MyISAM;

DROP TABLE IF EXISTS name_link CASCADE;
CREATE TABLE `name_link` (
	`id` INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`md5sum` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE KEY,
	`nmid` INTEGER(7) UNSIGNED NOT NULL,
	INDEX `name_link_md5sum` (`md5sum`),
	INDEX `name_link_nmid` (`nmid`)
) ENGINE=MyISAM;

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=indent:cms=#%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
