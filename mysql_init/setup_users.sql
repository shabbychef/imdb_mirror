#
# Created: 2015.11.05
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

CREATE USER 'moe'@'%' IDENTIFIED BY 'movies4me';
GRANT ALL PRIVILEGES ON *.* TO 'moe'@'%'
    WITH GRANT OPTION;

CREATE USER 'mouser'@'%' IDENTIFIED BY 'icanhazdb';

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=indent:cms=#%s:syn=mysql:ft=mysql:ai:si:cin:nu:fo=croql:cino=p0t0c5(0:
