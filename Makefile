######################
# 
# Created: 2016.05.16
# Copyright: Steven E. Pav, 2016
# Author: Steven E. Pav
######################

############### FLAGS ###############

############## DEFAULT ##############

.DEFAULT_GOAL 	:= help

############## MARKERS ##############

.PHONY   : help 
.SUFFIXES: 
.PRECIOUS: 

############ BUILD RULES ############

help:  ## generate this help message
	@grep -P '^(([^\s]+\s+)*([^\s]+))\s*:.*?##\s*.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


README.md : README.Rmd 
	r -l knitr -e 'setwd("$(<D)");if (require(knitr)) { knit("$(<F)") }'

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=129:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:tags=.tags;:syn=make:ft=make:ai:si:cin:nu:fo=croqt:cino=p0t0c5(0:
