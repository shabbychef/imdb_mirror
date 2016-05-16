######################
# 
# Created: 2015.09.14
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav (shabbychef@gmail.com)
# SVN: $Id$
######################

############### FLAGS ###############

RAW_DIR 				:= /srv/imdb/ftp_raw
PROC_DIR				:= /srv/imdb/ftp_proc
SQLITE_DIR      := /srv/imdb/sqlite
SCRAPE_DIR      := /srv/imdb/scrape
STATE_D 				:= /srv/make

#FTP_URL 				 = ftp://ftp.fu-berlin.de/pub/misc/movies/database/
#FTP_URL 				 = ftp://ftp.sunet.se/pub/tv+movies/imdb/
FTP_URL 				 = ftp://ftp.funet.fi/pub/mirrors/ftp.imdb.com/pub/

NEEDED 					 = actors actresses directors distributors genres keywords movies mpaa-ratings-reasons 
NEEDED 					+= plot ratings release-dates running-times taglines writers business language 
NEEDED 					+= aka-titles quotes aka-names biographies

RAW_NEEDED 			 = $(patsubst %,$(RAW_DIR)/%.list.gz,$(NEEDED))
PROC_NEEDED 		 = $(patsubst %,$(PROC_DIR)/%.list.gz,$(NEEDED))

IMDB_RAW_SQLITE    = $(SQLITE_DIR)/raw_imdb.db
IMDB_PRUNE_SQLITE  = $(SQLITE_DIR)/proc_imdb.db

MYSQLDB_1_PORT_3306_TCP_ADDR 		?= 0.0.0.0
MYSQLDB_1_PORT_3306_TCP_PORT 		?= 23306
MYSQLDB_1_ENV_MYSQL_USER 				?= moe
MYSQLDB_1_ENV_MYSQL_PASSWORD 		?= movies4me
MYSQLDB_1_ENV_MYSQL_DATABASE 		?= IMDB
DBPRE                          = MYSQLDB_1

MYSQL 					?= /usr/bin/mysql

DB_HOST 						:= $($(DBPRE)_PORT_3306_TCP_ADDR)
DB_PORT 						:= $($(DBPRE)_PORT_3306_TCP_PORT)
DB_USER 						:= $($(DBPRE)_ENV_MYSQL_USER)
DB_PASS 						:= $($(DBPRE)_ENV_MYSQL_PASSWORD)
DB_DBAS 						:= $($(DBPRE)_ENV_MYSQL_DATABASE)

# 2FIX: should probably remove --database here and force users to specify,
# but whatever.
DB_MYSQL_FLAGS 			= --host=$(DB_HOST) --port=$(DB_PORT) --user=$(DB_USER) --password=$(DB_PASS) --database=$(DB_DBAS)

INIT_SENTINEL 				= $(STATE_D)/imdb.init
UNINIT_SENTINEL 			= $(STATE_D)/imdb.uninit
DOWNL_SENTINEL 				= $(STATE_D)/imdb.downloaded
PUT_SENTINEL 					= $(STATE_D)/imdb.put
UNPUT_SENTINEL 				= $(STATE_D)/imdb.unput

TTLINK_PUT_SENTINEL 				= $(STATE_D)/imdbtt.put
TTLINK_UNPUT_SENTINEL 			= $(STATE_D)/imdbtt.unput

############## DEFAULT ##############

default : help

############## MARKERS ##############

.PHONY   : help hang noop env flags 
.PHONY   : downloaded procd raw_sqlite sqlite sqlitecon mysql_init stuffed R
.SUFFIXES: 
.PRECIOUS: %.gz

############    MACROS   ############

# make a directory
MKDIR = mkdir -p $(1)

# warn new deps
#WARN_DEPS = $(warning newer deps are $(?))
WARN_DEPS = $(warning will build $@ ; newer deps are $(?))

define dbcall
	-$(MYSQL) $(DB_MYSQL_FLAGS) --execute="$(1)"
endef

############ SILLY RULES ############

help :
	@-echo "make downloaded         run a bunch of wget from imdb ftp site"
	@-echo "make procd              perl prune the list.gz files"
	@-echo "make raw_sqlite         make the (raw) sqlite file"
	@-echo "make sqlite             make the (pruned,final) sqlite file"
	@-echo "make sqlitecon          connect to the pruned sqlite file"
	@-echo "make mysql_init         initialize db"
	@-echo "make put                stash sqlite file into mysql db, touching sentinel"
	@-echo "make R                  call R locally"

env :
	env

flags :
	-echo $(DB_MYSQL_FLAGS)

# this is dumb. like it says on the box, makes it hang.
hang :
	tail -f /dev/null

noop : true

true :
	true

############ BUILD RULES ############

# initialize the database# FOLDUP
$(INIT_SENTINEL) : schema.sql
	<$< $(MYSQL) $(DB_MYSQL_FLAGS) > $@
	-rm $(UNINIT_SENTINEL)

mysql_init : $(INIT_SENTINEL) 

$(UNINIT_SENTINEL) : 
	$(call dbcall,DROP TABLE IF EXISTS name;)
	$(call dbcall,DROP TABLE IF EXISTS cast_info;)
	$(call dbcall,DROP TABLE IF EXISTS char_name;)
	$(call dbcall,DROP TABLE IF EXISTS company_name;)
	$(call dbcall,DROP TABLE IF EXISTS company_type;)
	$(call dbcall,DROP TABLE IF EXISTS info_type;)
	$(call dbcall,DROP TABLE IF EXISTS keyword;)
	$(call dbcall,DROP TABLE IF EXISTS movie_admissions;)
	$(call dbcall,DROP TABLE IF EXISTS movie_budgets;)
	$(call dbcall,DROP TABLE IF EXISTS movie_companies;)
	$(call dbcall,DROP TABLE IF EXISTS movie_gross;)
	$(call dbcall,DROP TABLE IF EXISTS movie_info;)
	$(call dbcall,DROP TABLE IF EXISTS movie_info_idx;)
	$(call dbcall,DROP TABLE IF EXISTS movie_keyword;)
	$(call dbcall,DROP TABLE IF EXISTS movie_link;)
	$(call dbcall,DROP TABLE IF EXISTS movie_opening_weekend;)
	$(call dbcall,DROP TABLE IF EXISTS movie_rentals;)
	$(call dbcall,DROP TABLE IF EXISTS movie_votes;)
	$(call dbcall,DROP TABLE IF EXISTS movie_weekend_gross;)
	$(call dbcall,DROP TABLE IF EXISTS movie_release_dates;)
	$(call dbcall,DROP TABLE IF EXISTS name;)
	$(call dbcall,DROP TABLE IF EXISTS person_info;)
	$(call dbcall,DROP TABLE IF EXISTS role_type;)
	$(call dbcall,DROP TABLE IF EXISTS title;)
	touch $@
	-rm $(INIT_SENTINEL)
	-rm $(PUT_SENTINEL)

# UNFOLD

### download# FOLDUP

# rigamarole so that make -j 5 works.
$(RAW_DIR)/%.gz :
	mkdir -p $(@D)
	MYTMP=$$(mktemp -d /tmp/imdb_scrape_XXXXXXXXXXXXXXXX) ; \
		wget -r --progress=dot:giga --no-verbose -P $$MYTMP \
		--accept="$(@F)" \
		--waitretry=60 --retry-connrefused --timestamping --backups=2 \
		--random-wait --wait=10 \
		--no-directories --no-host-directories --level 1 \
		"$(FTP_URL)" ; \
	mv $$MYTMP/$(@F) $(RAW_DIR) ; \
	rm -rf $$MYTMP

$(DOWNL_SENTINEL) : $(RAW_NEEDED)
	touch $@

downloaded : $(DOWNL_SENTINEL) 
# UNFOLD

### prune out TV shows and such# FOLDUP
% : %.gz 
	gunzip %<

$(PROC_DIR)/actors.list.gz : $(RAW_DIR)/actors.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^\s+"/ || /^\s.+\((TV|VG|V)\)/ || print' | gzip > $@

$(PROC_DIR)/actresses.list.gz : $(RAW_DIR)/actresses.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^\s+"/ || /^\s.+\((TV|VG|V)\)/ || print' | gzip > $@

$(PROC_DIR)/directors.list.gz : $(RAW_DIR)/directors.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^\s+"/ || /^\s.+\((TV|VG|V)\)/ || print' | gzip > $@

$(PROC_DIR)/writers.list.gz : $(RAW_DIR)/writers.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^\s+"/ || /^\s.+\((TV|VG|V)\)/ || print' | gzip > $@

$(PROC_DIR)/language.list.gz : $(RAW_DIR)/language.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^\s+"/ || /^\s.+\((TV|VG|V)\)/ || print' | gzip > $@

$(PROC_DIR)/movies.list.gz : $(RAW_DIR)/movies.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || /\((TV|VG|V)\)\t/ || /{{SUSPENDED}}/ || print' | gzip > $@

$(PROC_DIR)/distributors.list.gz : $(RAW_DIR)/distributors.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || /\((TV|VG|V)\)\t/ || print' | gzip > $@


$(PROC_DIR)/keywords.list.gz : $(RAW_DIR)/keywords.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || print' | gzip > $@

$(PROC_DIR)/genres.list.gz : $(RAW_DIR)/genres.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || print' | gzip > $@

$(PROC_DIR)/release-dates.list.gz : $(RAW_DIR)/release-dates.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || print' | gzip > $@

$(PROC_DIR)/running-times.list.gz : $(RAW_DIR)/running-times.list.gz
	mkdir -p $(@D)
	gunzip -c $< | perl -ne '/^"/ || print' | gzip > $@

$(PROC_DIR)/mpaa-ratings-reasons.list.gz : $(RAW_DIR)/mpaa-ratings-reasons.list.gz
	mkdir -p $(@D)
	cp $< $@

# take all of these, do not modify them:
$(PROC_DIR)/business.list.gz : $(RAW_DIR)/business.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/plot.list.gz : $(RAW_DIR)/plot.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/taglines.list.gz : $(RAW_DIR)/taglines.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/ratings.list.gz : $(RAW_DIR)/ratings.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/aka-titles.list.gz : $(RAW_DIR)/aka-titles.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/quotes.list.gz : $(RAW_DIR)/quotes.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/aka-names.list.gz : $(RAW_DIR)/aka-names.list.gz
	mkdir -p $(@D)
	cp $< $@

$(PROC_DIR)/biographies.list.gz : $(RAW_DIR)/biographies.list.gz
	mkdir -p $(@D)
	cp $< $@

procd : $(PROC_NEEDED)

# UNFOLD

### raw files to sqlite via imdbpy2sql# FOLDUP
# first move the file out of the way o/w sqlite is very slow.
# c.f. http://stackoverflow.com/a/3143729/164611
$(IMDB_RAW_SQLITE) : $(PROC_NEEDED)
	mkdir -p $(@D)
	@-[ -e "$(IMDB_RAW_SQLITE)" ] && mv -f $(IMDB_RAW_SQLITE) $$(mktemp -u $(SQLITE_DIR)/raw_imdb_XXXXXXXXXXXXXXXXXXXXX.db) 
	/opt/imdbpy/imdbpy2sql.py -u sqlite:$@ --sqlite-transactions -d $(<D)

# UNFOLD

### prune porn from the sqlite# FOLDUP
$(IMDB_PRUNE_SQLITE) : $(IMDB_RAW_SQLITE)
	cp $< $@
	< prune.sql sqlite3 $@

# UNFOLD

raw_sqlite : $(IMDB_RAW_SQLITE) 

sqlite : $(IMDB_PRUNE_SQLITE) 

# see also /usr/share/doc/python-imdbpy/README.sqldb.gz
# scheme://[user[:password]@]host[:port]/database[?parameters]

# as predicted in the docs, using innodb was way too slow. so force to myisam
#foo : $(PROC_NEEDED)
#/opt/imdbpy/imdbpy2sql.py --mysql-force-myisam -u mysql://moe:movies4me@0.0.0.0:23306/movies -d $(<D)
#< prune.sql mysql -h 0.0.0.0 -P 23306 --password=movies4me -u moe movies

### put into mysql# FOLDUP
stuffed : $(PUT_SENTINEL) 

$(PUT_SENTINEL) : $(IMDB_PRUNE_SQLITE) $(INIT_SENTINEL)
	r converter.R $(DB_MYSQL_FLAGS) $< > $@
	<touchup.sql $(MYSQL) $(DB_MYSQL_FLAGS) >> $@
	-rm $(UNPUT_SENTINEL)

# UNFOLD

### remove from mysql# FOLDUP
# does this work? http://stackoverflow.com/q/25394493/164611
$(UNPUT_SENTINEL) : 
	$(call dbcall,TRUNCATE TABLE name;)
	$(call dbcall,TRUNCATE TABLE cast_info;)
	$(call dbcall,TRUNCATE TABLE char_name;)
	$(call dbcall,TRUNCATE TABLE company_name;)
	$(call dbcall,TRUNCATE TABLE company_type;)
	$(call dbcall,TRUNCATE TABLE info_type;)
	$(call dbcall,TRUNCATE TABLE keyword;)
	$(call dbcall,TRUNCATE TABLE movie_admissions;)
	$(call dbcall,TRUNCATE TABLE movie_budgets;)
	$(call dbcall,TRUNCATE TABLE movie_companies;)
	$(call dbcall,TRUNCATE TABLE movie_gross;)
	$(call dbcall,TRUNCATE TABLE movie_info;)
	$(call dbcall,TRUNCATE TABLE movie_info_idx;)
	$(call dbcall,TRUNCATE TABLE movie_keyword;)
	$(call dbcall,TRUNCATE TABLE movie_link;)
	$(call dbcall,TRUNCATE TABLE movie_opening_weekend;)
	$(call dbcall,TRUNCATE TABLE movie_rentals;)
	$(call dbcall,TRUNCATE TABLE movie_votes;)
	$(call dbcall,TRUNCATE TABLE movie_weekend_gross;)
	$(call dbcall,TRUNCATE TABLE movie_release_dates;)
	$(call dbcall,TRUNCATE TABLE name;)
	$(call dbcall,TRUNCATE TABLE role_type;)
	$(call dbcall,TRUNCATE TABLE title;)
	touch $@
	-rm $(PUT_SENTINEL)

# UNFOLD

# the ttid links# FOLDUP
$(TTLINK_PUT_SENTINEL) : link_imdbtt.sql $(SCRAPE_DIR)/imdblinking2.tsv $(PUT_SENTINEL)
	<$< /usr/bin/mysql -s --local-infile $(DB_MYSQL_FLAGS) > $@
	-rm $(TTLINK_UNPUT_SENTINEL)

# careful with this! it nulls out all ttids!
$(TTLINK_UNPUT_SENTINEL) :
	$(call dbcall,UPDATE title SET ttid=NULL;)
	touch $@
	-rm $(TTLINK_PUT_SENTINEL)
# UNFOLD

#############  DEBUGGING  ###########

sqlitecon : $(IMDB_PRUNE_SQLITE)
	sqlite3 $<

R :
	echo "this is dumb, you know that?"
	R

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=129:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:tags=.tags;:syn=make:ft=make:ai:si:cin:nu:fo=croqt:cino=p0t0c5(0:
