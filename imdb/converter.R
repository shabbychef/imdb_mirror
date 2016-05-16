# /usr/bin/r
#
# This is the piece of code that reads a pruned sqlite file of the
# imdb data, and pushes to a MySQL db. Big stuff. JK.
#
# Created: 2015.09.17
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <shabbychef@gmail.com>
# Comments: Steven E. Pav

library(DBI)
library(RMySQL)
library(lubridate)
library(RSQLite)
suppressMessages(library(dplyr))

get_con <- function(host='0.0.0.0',user='moe',password='movies4me',
										dbname='movies',port=33633) {
	# just pass em on...
	con <- dbConnect(RMySQL::MySQL(), dbname=dbname, host=host,
									 port=as.numeric(port), user=user, password=password)
}

suppressMessages(library(docopt))       # we need docopt (>= 0.3) as on CRAN

doc <- "Usage: stuff_omdb.R [-v] [-H <HOST>] [-p <PORT>] [-u <USER>] [-P <PASSWORD>] [-d <DBNAME>] SQLITEDB 

-H HOST --host=HOST              Give the host name [default: 0.0.0.0]
-p PORT --port=PORT              Give the port number [default: 44844]
-u USER --user=USER              Give the user [default: moe]
-P PASSWORD --password=PASSWORD  Give the password [default: movies4me]
-d DBNAME --database=DBNAME      Give the database name [default: IMDB]
-v --verbose                     Be more verbose
-h --help                        show this help text"

opt <- docopt(doc)
# for testing:
#
# opt <- docopt(doc,args='--verbose /srv/godb/state/imdb/sqlite/proc_imdb.db')

get_db <- src_sqlite(opt$SQLITEDB)
put_db <- get_con(host=opt$host,user=opt$user,password=opt$password,
							 dbname=opt$database,port=as.numeric(opt$port))

getit <- function(nm) { retv <- as.data.frame(tbl(get_db, nm),n=-1) }
# this approach is probably doomed, b/c by default when R creates
# the table, it is InnoDB. We want MyISAM for speed.
# so eff it.
#putit2 <- function(df,nm,ft,indices=c()) { 
	## probably unecessary:
	#dbBegin(out_db)
	#retv <- dbWriteTable(put_db, value=df, name=nm, 
											 #row.names=FALSE, append=FALSE, overwrite=TRUE,
											 #field.types=ft)
	#lapply(indices,function(fld) {
				 #query <- paste0('ALTER TABLE ',nm,' ADD INDEX `',nm,'_idx_',fld,'` (`',fld,'`)')
				 #dbSendQuery(put_db,query)
											 #})

	#dbCommit(out_db)
#}

#got <- getit('name')
#rev <- putit2(got,'IMDb_name',ft=list(id='INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT',
																		 #name='VARCHAR(128)',
																		 #imdb_index='VARCHAR(12)',
																		 #imdb_id='INT UNSIGNED',
																		 #gender='VARCHAR(1)',
																		 #name_pcode_cf='VARCHAR(5)',
																		 #name_pcode_nf='VARCHAR(5)',
																		 #surname_pcode='VARCHAR(5)',
																		 #md5sum='VARCHAR(32)'),
						 #indices=c('name','imdb_id','name_pcode_cf','name_pcode_nf','surname_pcode'))

# instead, assume the schema has been applied, and truncate the table first.
#
# from what I can tell, overwrite=TRUE actually redefines the table schema.
# this is bad. append=TRUE overwrite=FALSE lets you predefine the schema.
# But it will not clear out data that already exists. what fucking bother.
putit <- function(df,nm,truncate_first=TRUE,transactional=FALSE) {
	if (truncate_first) {
		query <- paste0('TRUNCATE TABLE ',nm)
		dbSendQuery(put_db,query)
	}
	if (transactional) { dbBegin(put_db) }
	retv <- dbWriteTable(put_db, value=df, name=nm, 
											 row.names=FALSE, append=TRUE, overwrite=FALSE)
	if (transactional) { dbCommit(put_db) }
}

# just query the sqlite for nm, write it to nm,
# possibly modifying the data.frame first. cheezy peazy.
vanilla_copy <- function(nm,modifier=function(n) { n },...) {
	df <- getit(nm)
	df <- modifier(df)
	retv <- putit(df,nm,...)
}

boolfix <- function(x) { retv <- as.numeric(x) }

# complicated function to load (string) vote data and convert to numbers.#FOLDUP
# we need more regularization in here, not just in the votes,
# but everywhere. the types are for crap, and need to be fixed.
# the rating is a factor? last_updated are strings not proper dates?
# this applies elsewhere as well..
get_votes <- function() {
	in_votes <- getit(sql("SELECT movie_id,info FROM movie_info_idx WHERE info_type_id IN (SELECT id FROM info_type WHERE info='votes distribution')"))
	in_nvotes <- getit(sql("SELECT movie_id,info FROM movie_info_idx WHERE info_type_id IN (SELECT id FROM info_type WHERE info='votes')"))
	in_rating <- getit(sql("SELECT movie_id,info FROM movie_info_idx WHERE info_type_id IN (SELECT id FROM info_type WHERE info='rating')"))

	joint_v <- left_join(in_votes,in_nvotes,by=c('movie_id')) %>%
		rename(distribution=info.x,
					 votes=info.y)
	rm(in_votes,in_nvotes)

	joint_v <- left_join(joint_v,in_rating,by=c('movie_id')) %>%
		rename(rating=info)
	rm(in_rating)
	joint_v$rating <- as.numeric(as.character(joint_v$rating))

	joint_v <- collect(joint_v)
																			
# the codes are explained as follows:
#     "." no votes cast        "3" 30-39% of the votes  "7" 70-79% of the votes
#     "0"  1-9%  of the votes  "4" 40-49% of the votes  "8" 80-89% of the votes
#     "1" 10-19% of the votes  "5" 50-59% of the votes  "9" 90-99% of the votes
#     "2" 20-29% of the votes  "6" 60-69% of the votes  "*" 100%   of the votes
	charvotes <- t(matrix(unlist(strsplit(as.matrix(joint_v$distribution),'')),nrow=10))
	pctm <- matrix(0,nrow=nrow(charvotes),ncol=10)
	pctm[charvotes == '*'] <- 1
	isnum <- '0' <= charvotes & charvotes <= '9'
	pctm[isnum] <- (0.5 + as.numeric(charvotes[isnum])) / 10

	ssize <- as.numeric(joint_v$votes)

# now normalize b/c buckets may not add to 1.
	nsum <- rowSums(pctm)

	pctm <- pctm / nsum

# now compute the expected value. More convenient to turn on its side first.
	pctm <- t(pctm)

	Evote <- colSums(pctm * c(1:10))
	E2vote <- colSums(pctm * (c(1:10)^2))
	sdvote <- sqrt(pmax(0,E2vote - Evote^2))

	stderr <- sdvote / sqrt(ssize)

	put_pctm <- t(100 * pctm)

	votas <- data.frame(votes=ssize,
											rating=joint_v$rating,
											vote_mean=Evote,
											vote_sd=sdvote,
											vote_se=stderr,
											vote1=put_pctm[,1],
											vote2=put_pctm[,2],
											vote3=put_pctm[,3],
											vote4=put_pctm[,4],
											vote5=put_pctm[,5],
											vote6=put_pctm[,6],
											vote7=put_pctm[,7],
											vote8=put_pctm[,8],
											vote9=put_pctm[,9],
											vote10=put_pctm[,10],
											movie_id=joint_v$movie_id)
}#UNFOLD

grep_units <- function(instr) {
	# peel the units out;
	units <- sub('^\\s*(\\D+)\\s*[\\d,.]+.*$','\\1',perl=TRUE,instr)
	units <- sub('\\s+','',perl=TRUE,units)
	units <- sub('\\$,','$',perl=FALSE,units)
# assume dollars
	units[nchar(units) < 1] <- '$'
# no euros in latin1 !
	Encoding(units) <- 'UTF-8'
	units
}

grep_amounts <- function(instr) {
	# grep the amount...
	amount <- sub('^\\s*(\\D+)\\s*([\\d,.]+).*$','\\2',perl=TRUE,instr)
	# idiots sometimes write '35.000.000' to mean '35,000,000'. How can you tell?
	amount <- as.numeric(gsub(',','',amount))
	amount
}

# complicated function to load budget data and convert to numbers.#FOLDUP
get_budgets <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='budget')"))
	# peel the units, amount out;
	units <- grep_units(in_data$info)
	amount <- grep_amounts(in_data$info)

	budget <- data.frame(id=c(1:nrow(in_data)),
											 movie_id=in_data$movie_id,
											 amount=amount,
											 units=units,stringsAsFactors=FALSE)
	
	# we will take the mean over duplicates:
	mean_budget <- budget %>% 
		group_by(movie_id,units) %>% 
		summarize(amount=mean(amount,na.rm=TRUE)) %>%
		arrange(movie_id)

	retv <- as.data.frame(mean_budget,n=-1)
}
#UNFOLD

# date parser#FOLDUP
bad_date_parser <- function(strdat) {
	reldat <- lubridate::dmy(strdat)

	# get just year
	justyr <- (is.na(reldat)) & (nchar(strdat) > 0) & (!grepl('[a-zA-Z]',strdat))
	reldat[justyr] <- lubridate::ymd(paste0(strdat[justyr],'-12-31'))

	# get Month year
	justmoyr <- (is.na(reldat)) & (nchar(strdat) > 0) & grepl('^(September|October|November|December|January|February|March|April|May|June|July|August)\\s*(19|20)\\d{2}',perl=TRUE,ignore.case=TRUE,strdat)
	newdats <- lubridate::dmy(paste('1',strdat[justmoyr])) + months(1) - days(1) 
	reldat[justmoyr] <- newdats

	reldat
}#UNFOLD

# complicated function to load gross data and convert to numbers.#FOLDUP
get_gross <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='gross')"))

	# reissue? wot bother
	repat <- '\\((re-issue|re-release|2015 re-release|3D re-release)\\)'
	reissue <- grepl(repat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(repat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# except USA
	usapat <- '\\(\\s*except USA\\s*\\)'
	ex_usa <- grepl(usapat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(usapat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# sneak preview? 
	sppat <- '\\(sneak preview\\)'
	in_data$info <- gsub(sppat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# 1st part and 2nd part. kill em;
	pppat <- '\\((1st|2nd) part\\)'
	in_data$info <- gsub(pppat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	in_data$info <- sub('^\\s+','',in_data$info,perl=TRUE)
	in_data$info <- sub('\\s+$','',in_data$info,perl=TRUE)

	# peel the units, amount out;
	units <- grep_units(in_data$info)
	amount <- grep_amounts(in_data$info)

	locale <- toupper(sub('^\\s*(\\D+)\\s*([\\d,.]+)\\s*\\(([^\\(\\)]+).*\\)','\\3',perl=TRUE,in_data$info))

	qualifier <- sub('^\\s*\\D+\\s*[\\d,.]+\\s*\\([A-Za-z-\\s]+\\)(\\s+\\(([^\\)]+)\\))?(\\s*\\(.+\\)\\s*)?$','\\2',perl=TRUE,in_data$info)
	grdate <- bad_date_parser(qualifier)

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 units=units,
										 amount=amount,
										 locale=locale,
										 reissue=boolfix(reissue),
										 end_date=grdate,stringsAsFactors=FALSE)
}
#UNFOLD

valgrep <- function(pat,str,ignore.case=FALSE,perl=TRUE,...) {
	foundit <- grepl(pat,str,ignore.case=ignore.case,perl=perl,...)
	retv <- rep("",length(str))
	retv[foundit] <- sub(paste0('^.*(',pat,').*$'),'\\1',str[foundit],ignore.case=ignore.case,perl=perl,...)
	retv
}

# complicated function to load opening weekend data and convert to numbers.#FOLDUP
get_opening <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='opening weekend')"))

	# data look like this: ack!
	#  movie_id                                                                  info
	#1   166492                               $5,247 (USA) (29 March 2015) (1 screen)
	#2   233853                       $6,047,613 (USA) (5 October 1990) (481 screens)
	#3   233853                       $980,798 (USA) (10 February 1985) (169 screens)
	#4   711127 € 9,826 (Italy) (22 December 2002) (2 screens) (re-release) (limited)
	#5   546169                        $3,769,251 (USA) (21 December 1984) (1 screen)
	#6   136334                 $216,239 (USA) (5 May 1991) (11 screens) (re-release)

	# reissue? wot bother
	repat <- '\\((re-?issue|(20\\d{2}|3D)?\\s*re-?release)\\)'
	reissue <- grepl(repat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(repat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# get screen info;
	scpat <- '\\([\\d,]+\\s+screens?\\)'
	screens <- valgrep(scpat,in_data$info)
	in_data$info <- gsub(scpat,'',ignore.case=TRUE,perl=TRUE,in_data$info)
	screens <- sub('^\\(([\\d,]+)\\s+screens?\\)$','\\1',perl=TRUE,ignore.case=TRUE,screens)
	nscreens <- as.numeric(gsub(',','',screens))

	# do not care
	kilpat <- '\\(limited\\)'
	in_data$info <- gsub(kilpat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	in_data$info <- sub('^\\s+','',in_data$info,perl=TRUE)
	in_data$info <- sub('\\s+$','',in_data$info,perl=TRUE)

	# peel the units,amount out;
	units <- grep_units(in_data$info)
	amount <- grep_amounts(in_data$info)

	locale <- toupper(sub('^\\s*(\\D+)\\s*([\\d,.]+)\\s*\\(([^\\(\\)]+).*\\)','\\3',perl=TRUE,in_data$info))

	qualifier <- sub('^\\s*\\D+\\s*[\\d,.]+\\s*\\([A-Za-z-\\s]+\\)(\\s+\\(([^\\)]+)\\))?(\\s*\\(.+\\)\\s*)?$','\\2',perl=TRUE,in_data$info)
	grdate <- bad_date_parser(qualifier)

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 units=units,
										 amount=amount,
										 locale=locale,
										 screens=nscreens,
										 end_date=grdate,stringsAsFactors=FALSE)
}
#UNFOLD

# complicated function to load weekend gross data and convert to numbers.#FOLDUP
get_weekend <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='weekend gross')"))

	# data look like this: ack!
	#  movie_id                                        info
	#1   166492     $5,247 (USA) (29 March 2015) (1 screen)
	#2   233853    $62,368 (USA) (12 May 1985) (24 screens)
	#3   233853     $89,224 (USA) (5 May 1985) (40 screens)
	#4   233853  $68,073 (USA) (28 April 1985) (35 screens)
	#5   233853  $84,304 (USA) (21 April 1985) (35 screens)
	#6   233853 $713,343 (USA) (14 April 1985) (33 screens)

	# reissue? wot bother
	repat <- '\\((re-?issue|(20\\d{2}|3D)?\\s*re-?release|limited)\\)'
	reissue <- grepl(repat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(repat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# get screen info;
	scpat <- '\\([\\d,]+\\s+screens?\\)'
	screens <- valgrep(scpat,in_data$info)
	in_data$info <- gsub(scpat,'',ignore.case=TRUE,perl=TRUE,in_data$info)
	screens <- sub('^\\(([\\d,]+)\\s+screens?\\)$','\\1',perl=TRUE,ignore.case=TRUE,screens)
	nscreens <- as.numeric(gsub(',','',screens))

	in_data$info <- sub('^\\s+','',in_data$info,perl=TRUE)
	in_data$info <- sub('\\s+$','',in_data$info,perl=TRUE)

	# peel the units,amount out;
	units <- grep_units(in_data$info)
	amount <- grep_amounts(in_data$info)

	locale <- toupper(sub('^\\s*(\\D+)\\s*([\\d,.]+)\\s*\\(([^\\(\\)]+).*\\)','\\3',perl=TRUE,in_data$info))

	qualifier <- sub('^\\s*\\D+\\s*[\\d,.]+\\s*\\([A-Za-z-\\s]+\\)(\\s+\\(([^\\)]+)\\))?(\\s*\\(.+\\)\\s*)?$','\\2',perl=TRUE,in_data$info)
	grdate <- bad_date_parser(qualifier)

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 units=units,
										 amount=amount,
										 locale=locale,
										 screens=nscreens,
										 end_date=grdate,stringsAsFactors=FALSE)

	min_open <- retv %>% group_by(movie_id) %>% 
		summarize(first_open=min(end_date))
	retv <- left_join(retv,min_open,by='movie_id') 
	retv$days_open <- as.numeric(difftime(retv$end_date,retv$first_open,units=c("days")))
	retv <- retv %>% 
		select(-first_open)
	retv 
}
#UNFOLD

# complicated function to load rental data and convert to numbers.#FOLDUP
get_rentals <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='rentals')"))

	# data look like this: ack!
	#    movie_id                                          info
	#1     316631                              $1,100,000 (USA)
	#2     101295                              $4,586,000 (USA)
	#3     101295                   $1,365,000 (Non-USA) (1940)
	#4     233853                             $41,660,000 (USA)
	#5     248847                              $1,598,435 (USA)
	#6     421946                        $2,046,000 (Worldwide)

	# reissue? wot bother
	repat <- '\\((re-?issue|(20\\d{2}|3D)?\\s*re-?release|limited)\\)'
	in_data$info <- gsub(repat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# estimated
	eepat <- '\\(estimated\\)'
	estimated <- grepl(eepat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(eepat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# ex USA
	eepat <- '\\(except USA\\)'
	exusa <- grepl(eepat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(eepat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	in_data$info <- sub('^\\s+','',in_data$info,perl=TRUE)
	in_data$info <- sub('\\s+$','',in_data$info,perl=TRUE)

	# peel the units,amount out;
	units <- grep_units(in_data$info)
	amount <- grep_amounts(in_data$info)

	locale <- toupper(sub('^\\s*(\\D+)\\s*([\\d,.]+)\\s*\\(([^\\(\\)]+).*\\)','\\3',perl=TRUE,in_data$info))

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 units=units,
										 amount=amount,
										 locale=locale,
										 estimated=boolfix(estimated),
										 ex_usa=boolfix(exusa),stringsAsFactors=FALSE)
	retv 
}
#UNFOLD

# complicated function to load admissions data and convert to numbers.#FOLDUP
get_admissions <- function() {
	in_data <- getit(sql("SELECT movie_id,info FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='admissions')"))

	# data look like this: ack!
	#  movie_id                         info
	#1   212419                1,157 (Spain)
	#2   211355              530,911 (Spain)
	#3   380950                3,791 (Spain)
	#4   384316                6,037 (Spain)
	#5   222743 462,074 (Netherlands) (1960)
	#6   385612                  160 (Spain)

	# reissue? wot bother
	repat <- '\\((re-?issue|(20\\d{2}|3D)?\\s*re-?release|limited)\\)'
	in_data$info <- gsub(repat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	# ex USA
	eepat <- '\\(except USA\\)'
	exusa <- grepl(eepat,ignore.case=TRUE,perl=TRUE,in_data$info)
	in_data$info <- gsub(eepat,'',ignore.case=TRUE,perl=TRUE,in_data$info)

	in_data$info <- sub('^\\s+','',in_data$info,perl=TRUE)
	in_data$info <- sub('\\s+$','',in_data$info,perl=TRUE)

	# fake dollars b/c all the other code has done that.
	amount <- grep_amounts(paste0('$',in_data$info))

	locale <- toupper(sub('^\\s*([\\d,.]+)\\s*\\(([^\\(\\)]+).*\\)','\\2',perl=TRUE,in_data$info))
	locale[grepl('\\d',locale,perl=TRUE)] <- NA

	qualifier <- sub('^\\s*[\\d,.]+\\s*\\([A-Za-z-\\s]+\\)(\\s+\\(([^\\)]+)\\))?(\\s*\\(.+\\)\\s*)?$','\\2',perl=TRUE,in_data$info)
	grdate <- bad_date_parser(qualifier)

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 amount=amount,
										 locale=locale,
										 end_date=grdate,stringsAsFactors=FALSE)
	retv 
}
#UNFOLD

# complicated function to load release dates and grok them.#FOLDUP
get_releases <- function() {
	in_data <- getit(sql("SELECT movie_id,info,note FROM movie_info WHERE info_type_id IN (SELECT id FROM info_type WHERE info='release dates')"))

	# data look like this: ack!
	#| movie_id | info                           | note                                              |
	#+----------+--------------------------------+---------------------------------------------------+
	#|        2 | USA:20 January 2014            | (DVD premiere)                                    |
	#|        3 | USA:9 June 2005                | NULL                                              |
	#|        4 | France:May 2009                | (Cannes Film Festival)                            |
	#|        5 | USA:28 April 2010              | NULL                                              |
	#|        7 | USA:April 2014                 | NULL                                              |
	#|        9 | USA:4 May 2013                 | (Los Angeles Asian Pacific Film Festival)         |
	#|        9 | USA:23 June 2015               | (DVD and Blu-ray premiere)                        |

	locale <- toupper(gsub('^([^:]+):.+$','\\1',perl=TRUE,in_data$info))
	rdate <- bad_date_parser(gsub('^.+:','',perl=TRUE,in_data$info))

	retv <- data.frame(id=c(1:nrow(in_data)),
										 movie_id=in_data$movie_id,
										 locale=locale,
										 date=rdate,
										 is_premiere=boolfix(grepl('\\(premiere\\)',ignore.case=TRUE,perl=TRUE,in_data$note)),
										 note=in_data$note,stringsAsFactors=FALSE)

	## later split multiple infos into different rows. for now, fuck it.
	#n_infos <- vapply(gregexpr('\\(',retv$note),
										#FUN.VALUE=0L,
										#function(z) { ifelse(z[1] > 0,length(z),0L) })
	#n_infos[is.na(n_infos)] <- 0
	#dupl <- retv[n_infos > 1,]
	#unip <- retv[n_infos <= 1,]
	retv 
}
#UNFOLD

BIG_TRANSACTION <- TRUE

# block with TRANSACTION and COMMIT?
if (BIG_TRANSACTION) { dbBegin(put_db) }

system.time(ok_char_name <- vanilla_copy('char_name',
																		modifier = function(df) { 
																			df %>% 
																			rename(char_name_id=id) %>% 
																			rename(chid=imdb_id) %>%
																			select(-name_pcode_nf,-surname_pcode)
																	 	}))
system.time(ok_name <- vanilla_copy('name',
																		modifier = function(df) { 
																			df %>% 
																			rename(person_id=id) %>% 
																			rename(nmid=imdb_id) %>%
																			select(-name_pcode_cf,-name_pcode_nf,-surname_pcode)
																		}))
system.time(ok_aka_name <- vanilla_copy('aka_name',
																		modifier = function(df) { 
																			df %>% 
																			select(-name_pcode_cf,-name_pcode_nf,-surname_pcode)
																		}))

system.time(ok_title <- vanilla_copy('title',
																		modifier = function(df) { 
																			df %>% 
																			rename(movie_id=id) %>% 
																			rename(ttid=imdb_id) 
																	 	}))
system.time(ok_aka_title <- vanilla_copy('aka_title'))

system.time(ok_company_type <- vanilla_copy('company_type',
																		modifier = function(df) { df %>% rename(company_type_id=id) }))
system.time(ok_company_name <- vanilla_copy('company_name',
																		modifier = function(df) { 
																			df %>% 
																			rename(company_id=id) %>% 
																			rename(coid=imdb_id) %>%
																			select(-name_pcode_nf,-name_pcode_sf)
																		}))

system.time(ok_role_type <- vanilla_copy('role_type',
																		modifier = function(df) { df %>% rename(role_id=id) }))
system.time(ok_cast_info <- vanilla_copy('cast_info',
																		modifier = function(df) { df %>% rename(char_name_id=person_role_id) }))
system.time(ok_info_type <- vanilla_copy('info_type',
																		modifier = function(df) { df %>% rename(info_type_id=id) }))
system.time(ok_keyword <- vanilla_copy('keyword',
																		modifier = function(df) { 
																			df %>% 
																			rename(keyword_id=id) %>%
																			select(-phonetic_code)
																	 	}))

system.time(ok_movie_keyword <- vanilla_copy('movie_keyword'))
system.time(ok_movie_info <- vanilla_copy('movie_info'))
system.time(ok_movie_info_idx <- vanilla_copy('movie_info_idx'))
system.time(ok_movie_companies <- vanilla_copy('movie_companies'))
system.time(ok_person_info <- vanilla_copy('person_info'))

# do movie_votes
# this one is not vanilla!
system.time(votas <- get_votes())
ok_movie_votes <- putit(votas,'movie_votes')
rm(votas)

# now budget and gross and retail and whatnot.
system.time(budgets <- get_budgets())
ok_movie_budgets <- putit(budgets,'movie_budgets')
rm(budgets)

system.time(gross <- get_gross())
ok_movie_gross <- putit(gross,'movie_gross')
rm(gross)

system.time(opn <- get_opening())
ok_movie_opening_weekend <- putit(opn,'movie_opening_weekend')
rm(opn)

system.time(wgs <- get_weekend())
ok_movie_weekend_gross <- putit(wgs,'movie_weekend_gross')
rm(wgs)

system.time(rts <- get_rentals())
ok_movie_rentals <- putit(rts,'movie_rentals')
rm(rts)

system.time(ads <- get_admissions())
ok_movie_admissions <- putit(ads,'movie_admissions')
rm(ads)

system.time(rds <- get_releases())
ok_movie_admissions <- putit(rds,'movie_release_dates')
rm(rds)

# block with TRANSACTION and COMMIT?
if (BIG_TRANSACTION) { dbCommit(put_db) }

# at some point, fill in the dob from the person_info table...

# mental note: try to be smarter about error'ing 

# cleanup#FOLDUP
tryCatch({dbDisconnect(get_db)},error=function(e) { NULL })
tryCatch({dbDisconnect(put_db)},error=function(e) { NULL })
#UNFOLD

#for vim modeline: (do not edit)
# vim:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:syn=r:ft=r
