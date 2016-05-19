######################
# 
# Created: 2016.05.16
# Copyright: Steven E. Pav, 2016
# Author: Steven E. Pav
######################

############### FLAGS ###############

DOCKER 						?= $(shell which docker)

PKG_NAME 					:= imdb_mirror
PKG_LCNAME 				:= $(shell echo $(PKG_NAME) | tr 'A-Z' 'a-z')

############## TARGETS ##############

MD_TARGETS 			 = README.md seasonality.md
HTML_TARGETS 		 = $(patsubst %.md,%.html,$(MD_TARGETS))

############## DEFAULT ##############

.DEFAULT_GOAL 	:= help

############## MARKERS ##############

.PHONY   : help viewit
.SUFFIXES: 
.PRECIOUS: 

############ BUILD RULES ############

help:  ## generate this help message
	@grep -P '^(([^\s]+\s+)*([^\s]+))\s*:.*?##\s*.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

$(MD_TARGETS) : %.md : %.Rmd
	r -l knitr -e 'setwd("$(<D)");if (require(knitr)) { knit("$(<F)") }'

$(HTML_TARGETS) : %.html : %.md
	pandoc -f markdown_github -t html -o $@ $<

%.view : %.html
	xdg-open file://$$(pwd)/$<

# this requires an internet connection, so suck it
olviewit : README.md ## view the README.md locally
	$(DOCKER) run -d -p 0.0.0.0:9929:6419 --name $(PKG_LCNAME) -v $$(pwd):/srv/grip/wiki:ro shabbychef/grip
	xdg-open http://0.0.0.0:9929
	@echo "to stop, run"
	@echo 'docker rm $$(docker stop $(PKG_LCNAME))'

viewit : README.view ## view the README.html locally w/out internet connection

localcon : ## open a mysql connection to the database 
	mysql -s --host=0.0.0.0 --port=23306 --user=moe --password=movies4me IMDB

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=129:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:tags=.tags;:syn=make:ft=make:ai:si:cin:nu:fo=croqt:cino=p0t0c5(0:
