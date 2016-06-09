# /usr/bin/r
#
# shiny comp page, server
#
# Created: 2015.09.10
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <steven@corecast.io>
# Comments: Steven E. Pav

last_upd <<- 1.0e9
savev <<- NULL

library(shiny)
library(ggplot2)
library(reshape2)
library(dplyr)
library(Matrix)
# for debugging:
library(shinyAce)

opt <- list(host=Sys.getenv('MYSQLDB_1_PORT_3306_TCP_ADDR'),
						port=as.numeric(Sys.getenv('MYSQLDB_1_PORT_3306_TCP_PORT')),
						user=Sys.getenv('MYSQLDB_1_ENV_MYSQL_USER',unset='moe'),
						password=Sys.getenv('MYSQLDB_1_ENV_MYSQL_PASSWORD',unset='movies4me'),
						dbname=Sys.getenv('MYSQLDB_1_ENV_DATABASE',unset='IMDB'))

# c.f. http://stackoverflow.com/a/8703024/164611
# e = local({load(srcf); environment()})
# tools:::makeLazyLoadDB(e, "New")

applylink <- function(titl,itt) {
	rv <- if (is.na(itt)) { 
		#as.character(a(titl,href=paste0("http://www.imdb.com/xml/find?json=0&nr=1&tt=on&q=",gsub('\\s+','+',perl=TRUE,titl)),target="_blank"))
		as.character(a(titl,href=paste0("http://www.imdb.com/find?q=",gsub('\\s+','+',perl=TRUE,titl)),target="_blank"))
	} else { 
		as.character(a(titl,href=paste0("http://www.imdb.com/title/tt",itt),target="_blank")) 
	}
}

# Define server logic 
shinyServer(function(input, output) {
	#cat('server!\n',file='/tmp/shiny.err')

	output$debuggin <- renderUI({
		helpText("I say to you:",
						 "keyword: ",input$keyword,
						 "writer: ",input$writer,
						 "cast: ",input$cast,
						 'und so weiter')
	})


	get_cursor <- reactive({
		con <- src_mysql(opt$dbname,host=opt$host,port=as.numeric(opt$port),user=opt$user,password=opt$password)
		con
	})

	grep_cast <- reactive({
		con <- get_cursor()

		if (nzchar(input$cast_grep)) {
			pyear <- as.numeric(input$prod_year)
			minpy <- min(pyear)
			maxpy <- max(pyear)

			nameinfo <- tbl(con,'name') %>%
				select(person_id,name,gender,dob) %>% 
				filter(name %regexp% input$cast_grep) 

			precasts <- tbl(con,'role_type') %>% 
				filter(role %in% c('actor','actress')) %>%
				select(role_id) %>% 
				left_join(tbl(con,'cast_info') %>% 
								select(movie_id,person_id,role_id,nr_order),
								by='role_id') %>%
				select(movie_id,person_id,nr_order) 

			casts <- nameinfo %>%
				left_join(precasts,by='person_id') %>%
				collect() %>%
				distinct(movie_id,person_id) %>%
				select(-person_id) 

			allt <- tbl(con,'title') %>% 
				filter(production_year >= minpy, production_year <= maxpy) %>%
				select(movie_id,title,imdb_index,ttid,production_year) %>% 
				collect() 

			casto <- casts %>% 
				inner_join(allt,by='movie_id') %>%
				rename(cast=name)
		} else {
			casto <- data.frame(movie_id=integer(0),
													person_id=integer(0),
													nr_order=numeric(0),
													cast=character(0),
													imdb_index=character(0),
													gender=character(0),
													title=character(0),
													ttid=integer(0),
													production_year=integer(0),
													stringsAsFactors=FALSE)
		}
		casto <- casto %>%
				mutate(primary_title=TRUE)
	})

	#output$cast_hits <- renderUI({
		#casto <- grep_cast()
		#if (nrow(casto) > 0) {
			#helpText('first guy is ',casto[1,]$cast)
		#} else {
			#helpText('none')
		#}
	#})

	grep_diro <- reactive({
		con <- get_cursor()

		if (nzchar(input$diro_grep)) {
			pyear <- as.numeric(input$prod_year)
			minpy <- min(pyear)
			maxpy <- max(pyear)

			nameinfo <- tbl(con,'name') %>%
				select(person_id,name,gender) %>% 
				filter(name %regexp% input$diro_grep) 

			precasts <- tbl(con,'role_type') %>% 
				filter(role == 'director') %>%
				select(role_id) %>% 
				left_join(tbl(con,'IMDb_cast_info') %>% 
								select(movie_id,person_id,role_id),
								by='role_id') %>%
				select(movie_id,person_id)

			casts <- nameinfo %>%
				left_join(precasts,by='person_id') %>%
				collect() %>%
				distinct(movie_id,person_id) %>%
				select(-person_id) 

			allt <- tbl(con,'title') %>% 
				filter(production_year >= minpy, production_year <= maxpy) %>%
				select(movie_id,title,imdb_index,ttid,production_year) %>% 
				collect() 

			casto <- casts %>% 
				inner_join(allt,by='movie_id') %>%
				rename(diro=name)
		} else {
			casto <- data.frame(movie_id=integer(0),
													person_id=integer(0),
													diro=character(0),
													imdb_index=character(0),
													gender=character(0),
													title=character(0),
													ttid=integer(0),
													production_year=integer(0),
													stringsAsFactors=FALSE)
		}
		casto <- casto %>%
				mutate(primary_title=TRUE)
	})

	grep_titles <- reactive({
		if (nzchar(input$title_grep)) {
			con <- get_cursor()
			pyear <- as.numeric(input$prod_year)
			minpy <- min(pyear)
			maxpy <- max(pyear)

			allt <- tbl(con,'title') %>% 
				filter(production_year >= minpy, production_year <= maxpy) %>%
				filter(title %regexp% input$title_grep) %>%
				select(movie_id,title,imdb_index,ttid,production_year) %>% 
				collect() 

			trut <- allt %>% 
				filter(grepl(input$title_grep,title,ignore.case=TRUE)) %>%
				mutate(primary_title=TRUE)

			if (input$primary_title_only) {
				subt <- trut
			} else {
				akat <- tbl(con,'aka_title') %>%
					select(movie_id,title) %>%
					filter(title %regexp% input$title_grep) %>%
					collect() %>%
					mutate(primary_title=FALSE) %>%
					left_join(allt %>% select(-title),by='movie_id')

				subt <- rbind(akat,trut) %>%
					arrange(title,primary_title) 
			}
		} else {
			subt <- data.frame(movie_id=integer(0),
												 title=character(0),
												 imdb_index=character(0),
												 ttid=integer(0),
												 production_year=integer(0),
												 primary_title=logical(0),
												 stringsAsFactors=FALSE)
		}

		subt
	})

	load_titles <- reactive({
		btitl <- grep_titles() %>%
			mutate(cast='',diro='')

		bcast <- grep_cast() %>%
			select(movie_id,title,imdb_index,ttid,production_year,primary_title,cast) %>%
			mutate(diro='')

		bdiro <- grep_diro() %>%
			select(movie_id,title,imdb_index,ttid,production_year,primary_title,diro) %>%
			mutate(cast='')

		con <- get_cursor()


		# ideally you would want all search information joined
		# earlier on so that if you searched for the title, cast,
		# _and_ director, they would all show up in the same rows...
		subt <- rbind(btitl,bcast,bdiro) %>%
			arrange(desc(diro),desc(cast)) %>%
			distinct(movie_id)

		ok_mid <- subt$movie_id

		if (length(ok_mid) == 0) {
			subt <- subt %>% mutate(budget=NA)
		} else {
			mbud <- tbl(con,'movie_budgets') %>% 
				filter(units=='$') %>% 
				select(movie_id,amount) %>%
				rename(budget=amount)
			if (length(ok_mid) == 1) {
				mbud <- mbud %>%
					filter(movie_id == ok_mid) 
			} else {
				mbud <- mbud %>%
					filter(movie_id %in% ok_mid)
			}
			subt <- subt %>% 
				left_join(mbud %>% collect(),by='movie_id')
		}

		if (length(ok_mid) == 0) {
			subt <- subt %>% mutate(votes_peryr=NA)
		} else {
			if (length(ok_mid) == 1) {
				vpy <- tbl(con,'votes_per_year') %>% 
					filter(movie_id == ok_mid) 
			} else {
				vpy <- tbl(con,'votes_per_year') %>% 
					filter(movie_id %in% ok_mid)
			}

			vpy <- vpy %>% 
				filter((input$min_vpy <= 5) | (vpy >= input$min_vpy)) %>%
				collect() %>%
				rename(votes_peryr=vpy) %>%
				mutate(votes_peryr=signif(votes_peryr,2))

			subt <- subt %>% 
				inner_join(vpy,by='movie_id')

			ok_mid <- subt$movie_id
		}

		if (length(ok_mid) == 0) {
			subt <- subt %>% mutate(tagline=NA_character_)
		} else {
			if (length(ok_mid) == 1) {
				jointo <- tbl(con,'movie_info') %>% 
									select(movie_id,info_type_id,info) %>%
									filter(movie_id == ok_mid)
			} else {
				jointo <- tbl(con,'movie_info') %>% 
									select(movie_id,info_type_id,info) %>%
									filter(movie_id %in% ok_mid)
			}

			taglos <- tbl(con,'info_type') %>% 
				filter(info=='taglines')  %>% 
				select(info_type_id) %>% 
				left_join(jointo,by='info_type_id') %>%
				select(movie_id,info) %>%
				collect() %>%
				rename(tagline=info) %>%
				mutate(tagline=paste0('"',tagline,'"')) %>%
				group_by(movie_id) %>% 
				summarize(tagline=paste0(tagline,collapse='\n')) %>%
				ungroup()

			subt <- subt %>% 
				left_join(taglos,by='movie_id')
		}

		# you have to do arrange here b/c the row selection requires it be the same
		# elsewhere, btw.
		subt <- subt %>%
			select(title,primary_title,imdb_index,production_year,budget,votes_peryr,movie_id,tagline,ttid,cast,diro) %>%
			arrange(desc(votes_peryr),desc(production_year))

		subt
	})

	get_titles <- reactive({
		if (last_upd <= as.numeric(Sys.time()) - 1) {
			retv <- load_titles()
			savev <<- retv
			last_upd <- as.numeric(Sys.time())
		} else {
			retv <- savev
		}
		retv
	})

	## 2FIX: do something with row selections...
	
	# table of comparables #FOLDUP
	output$titletable <- DT::renderDataTable({
		dspv <- get_titles()
		dspv$title <- mapply(applylink,dspv$title,dspv$ttid) 
		dspv$title <- ifelse(!is.na(dspv$tagline) & nzchar(dspv$tagline),paste0(dspv$title,' (<em>',dspv$tagline,'</em>)'),dspv$title)
		dspv <- dspv %>% 
			select(-ttid,-tagline) %>%
			select(title,imdb_index,production_year,cast,diro,budget,votes_peryr,movie_id) %>%
			rename(director=diro)

		# for this javascript shiznit, recall that javascript starts
		# counting at zero!
		#
		# cf 
		# col rendering: http://rstudio.github.io/DT/options.html
		# https://github.com/jcheng5/shiny-jsdemo/blob/master/ui.r
		#
		# I tried accounting.js, but it was slow as fucking hell:
		# http://openexchangerates.github.io/accounting.js/
		DT::datatable(dspv,
									caption='Matching films. Select one row to see detailed data in the other tabs.',
									escape=FALSE,
									rownames=FALSE,
									options=list(paging=TRUE,
															 pageLength=20,
										columnDefs=list(list(
										targets=c(5,6),
										render=JS("function(data,type,row,meta) {",
															"return data>999999.99 ? data/1000000 + 'M' : (data > 999.99 ? data/1000 + 'K':data) }"
															))))
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; synop data...#FOLDUP
	output$synoptable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		synops <- tbl(con,'info_type') %>% 
			filter(info=='plot')  %>% 
			select(info_type_id) %>% 
			left_join(tbl(con,'movie_info') %>% 
							select(movie_id,info_type_id,info) %>%
							filter(movie_id==ok_id),
							by='info_type_id') %>%
			select(movie_id,info) %>%
			collect() %>% 
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			rename(plot=info) %>%
			select(title,plot)

		DT::datatable(synops,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD


	# if rows are selected; genre data...#FOLDUP
	output$genretable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		genres <- tbl(con,'info_type') %>% 
			filter(info=='genres')  %>% 
			select(info_type_id) %>% 
			left_join(tbl(con,'IMDb_movie_info') %>% 
							select(movie_id,info_type_id,info) %>%
							filter(movie_id==ok_id),
							by='info_type_id') %>%
			select(movie_id,info) %>%
			collect() %>% 
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			rename(genre=info) %>%
			select(title,genre)

		DT::datatable(genres,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; cast data...#FOLDUP
	output$casttable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		casts <- tbl(con,'role_type') %>% 
			filter(role %in% c('actor','actress')) %>%
			select(role_id) %>% 
			left_join(tbl(con,'cast_info') %>% 
							select(movie_id,person_id,role_id,nr_order) %>%
							filter(movie_id==ok_id),
							by='role_id') %>%
			select(movie_id,person_id,nr_order) %>%
			left_join(tbl(con,'name') %>%
								select(person_id,name,imdb_index,gender),
								by='person_id') %>%
			select(-person_id) %>%
			collect() %>% 
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			arrange(nr_order)

		DT::datatable(casts,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; director data...#FOLDUP
	output$directortable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		diros <- tbl(con,'role_type') %>% 
			filter(role=='director') %>%
			select(role_id) %>% 
			left_join(tbl(con,'cast_info') %>% 
							select(movie_id,person_id,role_id,nr_order) %>%
							filter(movie_id==ok_id),
							by='role_id') %>%
			select(movie_id,person_id,nr_order) %>%
			left_join(tbl(con,'name') %>%
								select(person_id,name,imdb_index,gender),
								by='person_id') %>%
			select(-person_id) %>%
			collect() %>% 
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			arrange(nr_order)

		DT::datatable(diros,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; keywords data...#FOLDUP
	output$keywordstable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		keyos <- tbl(con,'movie_keyword') %>%
			filter(movie_id==ok_id) %>%
			select(movie_id,keyword_id) %>%
			left_join(tbl(con,'keyword') %>% 
								select(keyword_id,keyword),
								by='keyword_id') %>%
			select(-keyword_id) %>% 
			collect() %>%
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) 

		DT::datatable(keyos,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; bogross data...#FOLDUP
	output$bogrosstable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		bogro <- tbl(con,'movie_gross') %>%
			filter(movie_id==ok_id) %>%
			select(movie_id,units,locale,amount,end_date) %>%
			collect() %>%
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			mutate(end_date=as.Date(end_date,format='%Y-%m-%d')) %>%
			group_by(title,units,locale) %>%
			arrange(end_date) %>%
			summarize(end_date=last(end_date),
								amount=max(amount)) %>%
			ungroup() %>%
			arrange(locale,end_date) %>%
			select(title,locale,amount,units,end_date) 

		DT::datatable(bogro,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE,
										columnDefs=list(list(
										targets=c(2),
										render=JS("function(data,type,row,meta) {",
															"return data>999999.99 ? data/1000000 + 'M' : (data > 999.99 ? data/1000 + 'K':data) }"
															))))
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; boweeks data...#FOLDUP
	output$boweekstable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		keyos <- tbl(con,'movie_weekend_gross') %>%
			filter(movie_id==ok_id) %>%
			select(movie_id,units,locale,screens,days_open,amount,end_date) %>%
			collect() %>%
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			mutate(end_date=as.Date(end_date,format='%Y-%m-%d')) %>%
			arrange(locale,end_date) %>%
			select(title,locale,amount,units,screens,days_open,end_date) 

		DT::datatable(keyos,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE,
										columnDefs=list(list(
										targets=c(2,4),
										render=JS("function(data,type,row,meta) {",
															"return data>999999.99 ? data/1000000 + 'M' : (data > 999.99 ? data/1000 + 'K':data) }"
															))))
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; boweeks plot...#FOLDUP
	output$boweekplot <- renderPlot({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		keyos <- tbl(con,'movie_weekend_gross') %>%
			filter(movie_id==ok_id) %>%
			select(movie_id,units,locale,screens,days_open,amount,end_date) %>%
			collect() %>%
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) %>%
			mutate(end_date=as.Date(end_date,format='%Y-%m-%d')) %>%
			arrange(locale,end_date) %>%
			select(title,locale,amount,units,screens,days_open,end_date) 

		showus <- keyos %>% 
			filter(units=='$') 

			#geom_path(arrow=arrow(length=unit(0.20,'inches'),type='closed')) +
		#http://stackoverflow.com/a/3421563/164611
		ph <- ggplot(showus %>% arrange(days_open),aes(x=screens,y=amount,group=locale,color=locale)) + 
			geom_point() + 
			geom_segment(aes(xend=c(tail(screens, n=-1),NA),
											 yend=c(tail(amount, n=-1), NA)),
									 arrow=arrow(length=unit(0.15,'inches'),type='closed')) +
			scale_x_log10() + scale_y_log10()

		print(ph)

	},
	server=TRUE)#UNFOLD

	# if rows are selected; votes data...#FOLDUP
	output$votestable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		votos <- tbl(con,'movie_votes') %>%
			filter(movie_id==ok_id) %>%
			select(-id,-updated_at) %>%
			collect() %>%
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id) 

		DT::datatable(votos,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE,
										columnDefs=list(list(
										targets=c(0),
										render=JS("function(data,type,row,meta) {",
															"return data>999999.99 ? data/1000000 + 'M' : (data > 999.99 ? data/1000 + 'K':data) }"
															))))
									)
	},
	server=TRUE)#UNFOLD

	# if rows are selected; quotes data...#FOLDUP
	output$quotestable <- DT::renderDataTable({
		selrows <- input$titletable_rows_selected
		dspv <- get_titles()
		dspv <- dspv[min(selrows),]
		# now look up something...
		con <- get_cursor()
		ok_id <- dspv$movie_id

		quotos <- tbl(con,'info_type') %>% 
			filter(info=='quotes')  %>% 
			select(info_type_id) %>% 
			left_join(tbl(con,'IMDb_movie_info') %>% 
							select(movie_id,info_type_id,info) %>%
							filter(movie_id==ok_id),
							by='info_type_id') %>%
			select(movie_id,info) %>%
			collect() %>% 
			left_join(dspv %>% select(title,movie_id),by='movie_id') %>%
			select(-movie_id)

		DT::datatable(quotos,
									rownames=FALSE,
									escape=FALSE,
									options=list(paging=FALSE)
									)
	},
	server=TRUE)#UNFOLD

	# debugging#FOLDUP
	#output$debug_confession <- renderUI({
		#maj.date <- get_major_date()
		#retv <- helpText("major date is",maj.date)
	#})

	vals <- reactiveValues(ace_stdout = "")

	observe({
		input$runKey
		isolate(vals$ace_stdin <- eval(input$debug_ace_in))
		isolate(vals$ace_stdout <- eval(parse(text=vals$ace_stdin)))
	})
	
	# wrap these in <PRE> </PRE>?
	output$debug_ace_stdin <- renderText({
		retv <- paste0(vals$ace_stdin)
		retv
	})
	output$debug_ace_stdout <- renderText({
		retv <- paste0(vals$ace_stdout)
		retv
	})
	#UNFOLD

})

#for vim modeline: (do not edit)
# vim:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:syn=r:ft=r
