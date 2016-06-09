# /usr/bin/r
#
# shiny comp page, UI
#
# Created: 2015.09.10
# Copyright: Steven E. Pav, 2015
# Author: Steven E. Pav <steven@corecast.io>
# Comments: Steven E. Pav

library(shiny)
library(shinyAce)
library(shinythemes)
library(DT)

now.date <- Sys.Date()

# Define UI for ...
shinyUI(
	fluidPage(theme=shinytheme("spacelab"),#FOLDUP
		# for this, see: http://stackoverflow.com/a/22886762/164611
		# Application title
		tags$head(
					# load accounting js
					#tags$script(src='js/accounting.js'),
					tags$script(src='test.js'),
					# points for style:
					tags$style(".table .alignRight {color: black; text-align:right;}"),
					tags$link(rel="stylesheet", type="text/css", href="style.css")
		),
		titlePanel("Movie DB"),
		# tags$img(id = "logoimg", src = "logo.png", width = "200px"),
		sidebarLayout(#FOLDUP
			position="left",
		sidebarPanel(#FOLDUP
			width=2,
			h3('Parameters'),
			sliderInput("prod_year","Production Year:",sep='',min=1900,max=2015,value=c(2005,2015)),
			textInput("title_grep","Title:",value="Lords? of "),
			checkboxInput("primary_title_only","Search primary titles only",TRUE),
			textInput("cast_grep","Cast member:",value=""),
			textInput("diro_grep","Director:",value=""),
			#uiOutput("cast_hits"),
			hr(),
			helpText("Remove marginal films by filtering based on # of imdb votes:"),
			numericInput("min_vpy","Min. votes per year",min=0,max=10000,step=1,value=100)
			,hr()
			),#UNFOLD
	mainPanel(#FOLDUP
		width=9,
		tabsetPanel(
			tabPanel('titles',#FOLDUP
					DT::dataTableOutput('titletable')
					),#UNFOLD
			tabPanel('synopsis',#FOLDUP
					DT::dataTableOutput('synoptable')
					),#UNFOLD
			tabPanel('genre',#FOLDUP
					DT::dataTableOutput('genretable')
					),#UNFOLD
			tabPanel('cast',#FOLDUP
					DT::dataTableOutput('casttable')
					),#UNFOLD
			tabPanel('director',#FOLDUP
					DT::dataTableOutput('directortable')
					),#UNFOLD
			tabPanel('keywords',#FOLDUP
					DT::dataTableOutput('keywordstable')
					),#UNFOLD
			tabPanel('Box Office',#FOLDUP
					helpText('Reported Gross (IMDb):'),
					DT::dataTableOutput('bogrosstable')
					),#UNFOLD
			tabPanel('weekly',#FOLDUP
					helpText('Weekend box office gross:'),
					DT::dataTableOutput('boweekstable'),
					plotOutput('boweekplot')
					),#UNFOLD
			tabPanel('votes',#FOLDUP
					DT::dataTableOutput('votestable')
					),#UNFOLD
			tabPanel('quotes',#FOLDUP
					DT::dataTableOutput('quotestable')
					),#UNFOLD
			tabPanel('debuggin',#FOLDUP
				#uiOutput('debug_confession'),
				aceEditor("debug_ace_in", mode='r', value="lb <- rnorm(16);head(lb)",
									vimKeyBinding=TRUE,
									theme="github", fontSize=16, height="500px",
									hotkeys=list(runKey="F8|F9|F2|Ctrl-R")),
				# actionButton("debug_eval","Evaluate"),
				verbatimTextOutput('debug_ace_stdin'),
				verbatimTextOutput('debug_ace_stdout')
					)#UNFOLD
				)  # tabSetPanel
			)  # mainPanel#UNFOLD
		) # sidebarLayout#UNFOLD
	)  # fluidPAge#UNFOLD
)  # shinyUI

#for vim modeline: (do not edit)
# vim:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:syn=r:ft=r
