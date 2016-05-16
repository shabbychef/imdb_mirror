#
# Created: 2016.02.03
# Copyright: Steven E. Pav, 2016
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

START TRANSACTION;

USE IMDB;

#ALTER TABLE title CHANGE `title` `title` VARCHAR(234) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL;

DROP TEMPORARY TABLE IF EXISTS templink;
CREATE TEMPORARY TABLE templink (
	`ttid` INT(7) UNSIGNED NOT NULL AUTO_INCREMENT KEY,
	`imdb_index` VARCHAR(12),
	`production_year` INT(4) UNSIGNED,
	`title` varchar(244) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
	`akatitle` varchar(244) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
	`presentation` varchar(63) DEFAULT NULL,
	UNIQUE KEY `nodup` (`title`(150),`production_year`,`imdb_index`(10)),
	INDEX `tl_year` (`production_year`),
	INDEX `tl_presentation` (`presentation`)
) ENGINE=MyISAM;


# for testing:
#LOAD DATA LOCAL INFILE '/srv/godb/state/imdb/scrape/imdblinking2.tsv'
LOAD DATA LOCAL INFILE '/srv/imdb/scrape/imdblinking2.tsv'
IGNORE INTO TABLE `templink`
CHARACTER SET 'utf8'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
(@ttid,@iindex,@aka,@year,@ttl,`presentation`)
SET production_year=COALESCE(CAST(COALESCE(@year,1900) AS UNSIGNED INTEGER),1900),
imdb_index=COALESCE(@iindex,''),
akatitle=TRIM(BOTH '"' FROM TRIM(BOTH ' ' FROM @aka)),
`title`=REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(BOTH ' ' FROM @ttl),'&amp;','&'),'&quot;','"'),'&gt;','>'),'&lt','<'),
ttid=CAST(TRIM(LEADING 'tt' FROM @ttid) AS UNSIGNED INTEGER);

# wish I could just filter this on input...
DELETE FROM templink 
WHERE LENGTH(presentation) > 0 
OR production_year < 1900;

# now that it is reduced, modify it.
ALTER TABLE templink 
  ADD INDEX `tl_title` (`title`),
	ADD INDEX `tl_akatitle` (`akatitle`);

# link on title, index, year
UPDATE title AS ttt
	INNER JOIN templink as zzz
	ON ttt.title=zzz.title 
	AND COALESCE(ttt.production_year,1900)=zzz.production_year
	AND COALESCE(ttt.imdb_index,'')=zzz.imdb_index
  SET ttt.ttid = zzz.ttid;

#SELECT COUNT(*) 
#FROM title
#WHERE NOT ttid IS NULL;
#SELECT COUNT(*) 
#FROM title
#WHERE ttid IS NULL;

UPDATE title AS ttt
	INNER JOIN templink as zzz
	ON ttt.title=zzz.akatitle 
	AND COALESCE(ttt.production_year,1900)=zzz.production_year
	AND COALESCE(ttt.imdb_index,'')=zzz.imdb_index
  SET ttt.ttid = zzz.ttid
  WHERE ttt.ttid IS NULL;

# done.
DROP TEMPORARY TABLE IF EXISTS templink;

COMMIT;

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=indent:cms=#%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
