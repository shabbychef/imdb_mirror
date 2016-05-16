#
# Created: 2016.02.11
# Copyright: Steven E. Pav, 2016
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

# after the IMDB data has been imported, 
# do some SQL processing to freshen it.

START TRANSACTION;

USE IMDB

UPDATE name AS nnn
	INNER JOIN
	(SELECT person_id,COALESCE(STR_TO_DATE(info,'%d %M %Y'),
    STR_TO_DATE(info,'%M %Y'),
    STR_TO_DATE(info,'%Y'),
    STR_TO_DATE(REGEXP_REPLACE(info,'\\s*(ca?|circa)\.?\\s+',''),'%Y')) AS `dob` 
	FROM person_info 
	WHERE info_type_id IN 
	(SELECT info_type_id FROM info_type WHERE info REGEXP 'birth date')) as zzz 
	ON nnn.person_id=zzz.person_id
  SET nnn.dob = zzz.dob;

COMMIT;

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=indent:cms=--%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
