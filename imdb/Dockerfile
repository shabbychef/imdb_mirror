# imdb_scraper
#
# VERSION 0.1
#
# imdb_scraper
#
# Created: 2015.09.14
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav
# Comments: Steven E. Pav

#####################################################
# preamble# FOLDUP
FROM shabbychef/littler-onbuild
MAINTAINER Steven E. Pav, shabbychef@gmail.com
USER root
# UNFOLD

#####################################################
# set up imdbpy# FOLDUP
RUN (mkdir -p /opt/imdbpy ; \
	cp /usr/share/doc/python-imdbpy/examples/imdbpy2sql.py.gz /opt/imdbpy/ ; \
	gunzip /opt/imdbpy/imdbpy2sql.py.gz ; \
	chmod +x /opt/imdbpy/imdbpy2sql.py )
# UNFOLD

VOLUME /opt/imdb 
COPY Makefile *.R *.sql /opt/imdb/

#####################################################
# entry and cmd# FOLDUP
WORKDIR /opt/imdb
USER root

# Expose ssh?
#EXPOSE 22 

# always use array syntax:
ENTRYPOINT ["/usr/bin/make"]

# ENTRYPOINT and CMD are better together:
CMD ["help"]
# UNFOLD

#for vim modeline: (do not edit)
# vim:nu:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:syn=Dockerfile:ft=Dockerfile:fo=croql
