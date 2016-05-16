#
# Created: 2015.11.05
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

# nb utf8mb4 is a 'better' choice of unicode, but it consumes 4 bytes
# this can cause problems with unique keys. I think you can get around
# that with this http://stackoverflow.com/a/8747703/164611
#
# note also that collations sometimes cause equality of seemingly
# distinct characters. e.g. 'Ä'='A'. It appears that
# utf8mb4_bin compares 'binarily' and is very persnickety, not
# matching those chars.
# but utf8mb4_general_ci will match those...

CREATE DATABASE IF NOT EXISTS `IMDB`
	DEFAULT CHARACTER SET utf8mb4
	DEFAULT COLLATE utf8mb4_general_ci;

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=indent:cms=#%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
