

# IMDb Mirror

This is a 'mirror' of the IMDb database, stored in a mariadb
database. The data are downloaded from one of the IMDb FTP
mirrors, then processed to remove TV shows, porn, shorts, 
and 'insignificant' films (based on number of ratings).
The database and scraper are housed in `docker` containers
and orchestrated via `docker-compose` 

## Initialization

Prepare the `srv` directory where we will store the database
and the make state:


```bash
mkdir -p ./srv/imdb/mariadb ./srv/imdb/state/make ./srv/imdb/rw 
chmod -R 777 ./srv/imdb
```

Then use `docker-compose` to initialize the database.


```bash
docker-compose build
docker-compose up -d
sleep 2s && docker-compose ps
```

It may take a while to pull the image for `mariadb`. To check on the status
of your images, run


```bash
docker-compose ps
```

You should see something like the following:
```
         Name                       Command              State             Ports          
-----------------------------------------------------------------------------------------
imdbmirror_imdb_1         /usr/bin/make noop             Exit 0                           
imdbmirror_mariastate_1   /bin/true                      Exit 0                           
imdbmirror_mysqldb_1      /docker-entrypoint.sh mysqld   Up       0.0.0.0:23306->3306/tcp 
imdbmirror_state_1        /bin/true                      Exit 0                           
```

## Download

The commands to download, transform, and store the IMDb data are
run via a `Makefile` within the `docker` image `imdb`. The main command
of this `docker` image is `make`, so y
be run via:


```bash
alias imake='docker-compose run --rm imdb'
imake help
```

Creating a mirror works by the following steps:

1. Downloading files from the FTP mirror.
1. Processing them with perl to remove TV shows.
1. Stuffing them into a sqlite file with `imdb2sql.py`.
1. Removing porn, unpopular titles and shorts, as well as stranded actors and
	 directors.
1. Stuffing the remaining data into mariadb, interpreting some of the fields.

You can run them via:


```bash
# download:
imake -j 4 downloaded
# process 
imake -j 6 procd
# raw sqlite
imake raw_sqlite
# remove porn and so on:
imake sqlite
# stuff into mariadb:
imake stuffed
```

**Note** This can take a good long while. Depending on your internet connection, the 
download might take 20 minutes or more. Processing into sqlite may take around 10 to 
15 minutes, and then post-processing and loading into mariadb may take an hour. Also,
intermediate files will be kept around, saved in the `./srv/imdb/state` directory.
Having intermediate files allows you to change the code and rerun without forcing a
new download.

Now connect to the database and poke around:


```bash
mysql -s --host=0.0.0.0 --port=23306 --user=moe --password=movies4me IMDB
```

## What is in the database?

First, let us check the available tables:


```r
library(RMySQL)
library(dplyr)
library(knitr)
imcon <- src_mysql(host='0.0.0.0',user='moe',password='movies4me',dbname='IMDB',port=23306)
capt <- dbGetQuery(imcon$con,'SET NAMES utf8')
show(src_tbls(imcon))
```

```
##  [1] "aka_name"                  "aka_title"                 "cast_info"                
##  [4] "char_name"                 "company_name"              "company_type"             
##  [7] "info_type"                 "keyword"                   "movie_US_gross"           
## [10] "movie_admissions"          "movie_budgets"             "movie_companies"          
## [13] "movie_first_US_release"    "movie_gross"               "movie_info"               
## [16] "movie_info_idx"            "movie_keyword"             "movie_opening_weekend"    
## [19] "movie_premiere_US_release" "movie_raw_runtimes"        "movie_release_dates"      
## [22] "movie_rentals"             "movie_runtime"             "movie_votes"              
## [25] "movie_weekend_gross"       "name"                      "name_link"                
## [28] "person_info"               "role_type"                 "title"                    
## [31] "title_link"                "votes_per_year"
```

### Movie info

First, how many movies do we have:


```r
nmovies <- tbl(imcon,'title') %>%
	summarize(count=n()) 
print(nmovies)
```

```
## Source: mysql 5.5.5-10.1.13-MariaDB-1~jessie [moe@0.0.0.0:/IMDB]
## From: <derived table> [?? x 1]
## 
##     count
##     (dbl)
## 1  233061
## ..    ...
```

Now some information about each of the tables:



```r
library(RMySQL)
library(dplyr)
library(knitr)
imcon <- src_mysql(host='0.0.0.0',user='moe',password='movies4me',dbname='IMDB',port=23306)
capt <- dbGetQuery(imcon$con,'SET NAMES utf8')
show(src_tbls(imcon))
```

 [1] "aka_name"                  "aka_title"                 "cast_info"                
 [4] "char_name"                 "company_name"              "company_type"             
 [7] "info_type"                 "keyword"                   "movie_US_gross"           
[10] "movie_admissions"          "movie_budgets"             "movie_companies"          
[13] "movie_first_US_release"    "movie_gross"               "movie_info"               
[16] "movie_info_idx"            "movie_keyword"             "movie_opening_weekend"    
[19] "movie_premiere_US_release" "movie_raw_runtimes"        "movie_release_dates"      
[22] "movie_rentals"             "movie_runtime"             "movie_votes"              
[25] "movie_weekend_gross"       "name"                      "name_link"                
[28] "person_info"               "role_type"                 "title"                    
[31] "title_link"                "votes_per_year"           

```r
showtable <- function(tnam) {
  cat(sprintf('\n\n### %8s:\n',tnam))
	tbl(imcon,tnam) %>%
		left_join(tbl(imcon,'title') %>% select(movie_id,title),by='movie_id') %>%
    head() %>%
    kable(caption=tnam) %>%
		show()
}

movie_tables <- src_tbls(imcon) 
movie_tables <- movie_tables[grepl('^movie_',movie_tables)]
capt <- lapply(movie_tables,showtable)
```



### movie_US_gross:


| movie_id| gross_dollars|last_report_date |title                                                   |
|--------:|-------------:|:----------------|:-------------------------------------------------------|
|      313|       5.2e+04|2010-01-17       |$9.99                                                   |
|      323|       9.3e+03|2016-05-19       |$pent                                                   |
|      362|       1.3e+06|2015-05-03       |'71                                                     |
|      412|       7.1e+06|2016-05-19       |'Breaker' Morant                                        |
|      447|       1.1e+08|2016-05-19       |'Crocodile' Dundee II                                   |
|      498|       2.2e+06|1943-12-31       |'Gung Ho!': The Story of Carlson's Makin Island Raiders |


### movie_admissions:


| movie_id| id| amount|locale |end_date   |title           |
|--------:|--:|------:|:------|:----------|:---------------|
|   249155|  1|   1225|FRANCE |2016-01-26 |Fanny           |
|   249155|  2|   1128|FRANCE |2016-01-19 |Fanny           |
|   532035|  3|  92169|SPAIN  |NA         |Nobleza baturra |
|   166918|  4|   1152|FRANCE |2016-01-26 |César           |
|   166918|  5|   1094|FRANCE |2016-01-19 |César           |
|   124437|  6|    727|FRANCE |2015-04-14 |Camille         |


### movie_budgets:


| movie_id| id|units | amount|title         |
|--------:|--:|:-----|------:|:-------------|
|        2|  1|$     |    500|#             |
|       15|  2|$     |    500|#2 Chick      |
|       25|  3|$     |   1000|#30           |
|       41|  4|€     |   1500|#99           |
|       44|  5|€     |  10000|#ambigot      |
|       55|  6|$     |  20000|#bars4Justice |


### movie_companies:


| movie_id| id| company_id| company_type_id|note                                |title                                     |
|--------:|--:|----------:|---------------:|:-----------------------------------|:-----------------------------------------|
|       25|  5|          4|               1|(2015) (USA) (video)                |#30                                       |
|       39|  7|          6|               1|(2007) (India) (all media)          |#73, Shaanthi Nivaasa                     |
|       70|  9|          8|               1|(2016) (Mexico) (theatrical)        |#BuscandoaInés                            |
|      115| 11|         10|               1|(2014) (USA) (all media) (Internet) |#Hacked                                   |
|      122| 12|         11|               1|(2015) (worldwide) (video)          |#HeroIsTheNewBlack!                       |
|      124| 13|         12|               1|(2013) (Russia) (all media)         |#Hommes: True Story of the Thieves' World |


### movie_first_US_release:


| movie_id|date       |title                           |
|--------:|:----------|:-------------------------------|
|        2|2014-01-20 |#                               |
|        6|2015-12-12 |#1 at the Apocalypse Box Office |
|        7|2014-04-30 |#1 Beauty Nail Salon            |
|       11|2015-12-01 |#10007                          |
|       12|2015-07-30 |#1137                           |
|       15|2014-06-17 |#2 Chick                        |


### movie_gross:


| movie_id| id|units |  amount|locale    | reissue|end_date   |title                          |
|--------:|--:|:-----|-------:|:---------|-------:|:----------|:------------------------------|
|   800610|  1|ITL   | 2.4e+08|ITALY     |       0|NA         |The Silent Enemy               |
|    44754|  2|$     | 3.3e+06|USA       |       0|NA         |All Quiet on the Western Front |
|    58263|  3|$     | 1.0e+06|USA       |       0|NA         |Anna Christie                  |
|    58263|  4|$     | 4.9e+05|WORLDWIDE |       0|NA         |Anna Christie                  |
|   185421|  5|$     | 7.8e+04|USA       |       0|2001-12-09 |Der blaue Engel                |
|   185421|  6|$     | 6.9e+04|USA       |       0|2001-11-11 |Der blaue Engel                |


### movie_info:


| movie_id|     id| info_type_id|info                                                                                                                                                                                                                                                             |note |title |
|--------:|------:|------------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----|:-----|
|      269| 370439|           15|Dawn Divine: He could have killed me too, you know?::Joe Collins: That's right.::Dawn Divine: I hate him!::Joe Collins: Waste of time!::Dawn Divine: I don't care! I could kill him!::Joe Collins: Hey, stealing's a business, not a crusade.                    |NA   |$     |
|      269| 370440|           15|Granich: Can you gets these bottles into Copenhagan?::Candy Man: What is it?::Granich: Pure, consentrated, acid. From one ounce, they will make 300,000 capsules of LSD. If you put one of these into the water supply, all of Hamburg takes the trip!           |NA   |$     |
|      269| 370441|           15|[on the telephone]::Sarge: Yeah, I know the line is busy. Find out if Miss Divine is talking, or if the phone is out of order. Hello? Operator? [hangs up] Damn, Hamburg operators. Why the hell don't they learn English?                                       |NA   |$     |
|      269| 370442|           15|Sarge: [in an irritable voice as he disgustedly watches the Candy Man lean back and forth and crane his neck in various directions and climb around to look on different sides of the closet walls and tap the panelling with his knuckles] What're ya BUILDIN'? |NA   |$     |
|      269| 370443|           15|Mr. Kessel: [seeing Miss Devine's heavily-loaded grocery bag] Ahhhh, Fraulein! Soooo much to eat for such a little girl::Dawn Divine: [giggling] I have no willpower!                                                                                            |NA   |$     |
|      269| 370444|           15|Sarge: [seeing that Miss Devine is exiting the booth that he was planning to go into] Hey - - what're you doing in there?::Dawn Divine: [flashing a bright mischievous smile and replying in a pretend furtive whisper] Robbing a bank!                          |NA   |$     |


### movie_info_idx:


| movie_id|     id| info_type_id|info       |note |title                 |
|--------:|------:|------------:|:----------|:----|:---------------------|
|       39| 881598|           99|1000001103 |NA   |#73, Shaanthi Nivaasa |
|       39| 881599|          100|117        |NA   |#73, Shaanthi Nivaasa |
|       39| 881600|          101|6.4        |NA   |#73, Shaanthi Nivaasa |
|       41| 881607|           99|0.......08 |NA   |#99                   |
|       41| 881608|          100|13         |NA   |#99                   |
|       41| 881609|          101|9.2        |NA   |#99                   |


### movie_keyword:


| movie_id|  id| keyword_id|title                             |
|--------:|---:|----------:|:---------------------------------|
|       62| 115|        111|#Bitch, les filles et la violence |
|       62| 116|        112|#Bitch, les filles et la violence |
|       62| 117|        113|#Bitch, les filles et la violence |
|       62| 118|        114|#Bitch, les filles et la violence |
|       62| 119|        115|#Bitch, les filles et la violence |
|       75| 120|        116|#Coachella                        |


### movie_opening_weekend:


| movie_id| id|units | amount|locale | screens|end_date   |title              |
|--------:|--:|:-----|------:|:------|-------:|:----------|:------------------|
|   185421|  1|$     |   4808|USA    |       1|2001-07-22 |Der blaue Engel    |
|   185421|  2|$     |   6451|USA    |       1|2001-07-15 |Der blaue Engel    |
|   405541|  3|£     |   1901|UK     |       1|2004-02-15 |L'âge d'or         |
|   464463|  4|$     |   6123|USA    |       1|1931-03-14 |M                  |
|   488326|  5|$     |   7554|USA    |       1|2015-08-09 |Metropolitan       |
|   411775|  6|$     |   7526|USA    |       1|2012-05-13 |La grande illusion |


### movie_premiere_US_release:


| movie_id|date       |title         |
|--------:|:----------|:-------------|
|       55|2015-10-01 |#bars4Justice |
|      244|2016-01-24 |#UnitedWeWin. |
|      251|2016-12-31 |#WeFilmLA     |
|      269|1971-12-15 |$             |
|      336|2008-10-09 |& Teller      |
|      489|1935-04-18 |'G' Men       |


### movie_raw_runtimes:


| movie_id| rt|title                           |
|--------:|--:|:-------------------------------|
|        7|  5|#1 Beauty Nail Salon            |
|        6| 11|#1 at the Apocalypse Box Office |
|       11| 10|#10007                          |
|       18|  7|#23                             |
|       25|  6|#30                             |
|       28| 11|#47                             |


### movie_release_dates:


| movie_id| id|locale    |date       | is_premiere|note           |title                           |
|--------:|--:|:---------|:----------|-----------:|:--------------|:-------------------------------|
|        2|  1|USA       |2014-01-20 |           0|(DVD premiere) |#                               |
|        7|  2|USA       |2014-04-30 |           0|NA             |#1 Beauty Nail Salon            |
|        6|  3|AUSTRALIA |2015-07-31 |           0|NA             |#1 at the Apocalypse Box Office |
|        6|  4|USA       |2015-12-12 |           0|NA             |#1 at the Apocalypse Box Office |
|       11|  5|USA       |2015-12-01 |           0|NA             |#10007                          |
|       12|  6|USA       |2015-07-30 |           0|NA             |#1137                           |


### movie_rentals:


| movie_id| id|units |  amount|locale    | estimated| ex_usa|title                          |
|--------:|--:|:-----|-------:|:---------|---------:|------:|:------------------------------|
|    44754|  1|$     | 1500000|USA       |         0|      0|All Quiet on the Western Front |
|   745215|  2|$     | 1218000|WORLDWIDE |         0|      0|The Divorcee                   |
|   348571|  3|$     |  551000|USA       |         0|      0|In Gay Madrid                  |
|   348571|  4|$     |  398000|NON-USA   |         0|      0|In Gay Madrid                  |
|   892605|  5|$     | 2300000|WORLDWIDE |         0|      0|Whoopee!                       |
|   145575|  6|$     | 1500000|USA       |         0|      0|City Lights                    |


### movie_runtime:


| movie_id| runtime| minruntime| maxruntime| nruntimes|title                           |
|--------:|-------:|----------:|----------:|---------:|:-------------------------------|
|        6|      11|         11|         11|         1|#1 at the Apocalypse Box Office |
|        7|       5|          5|          5|         1|#1 Beauty Nail Salon            |
|       11|      10|         10|         10|         1|#10007                          |
|       18|       7|          7|          7|         1|#23                             |
|       25|       6|          6|          6|         1|#30                             |
|       28|      11|         11|         11|         1|#47                             |


### movie_votes:


| movie_id| id|updated_at          | votes| rating| vote_mean| vote_sd| vote_se| vote1| vote2| vote3| vote4| vote5| vote6| vote7| vote8| vote9| vote10|title                 |
|--------:|--:|:-------------------|-----:|------:|---------:|-------:|-------:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|-----:|------:|:---------------------|
|       39|  1|2016-05-17 13:19:07 |   117|    6.4|       6.7|     3.2|    0.30|    14|     5|     5|     5|     5|     5|    14|    14|     5|     32|#73, Shaanthi Nivaasa |
|       41|  2|2016-05-17 13:19:07 |    13|    9.2|       9.5|     2.0|    0.56|     5|     0|     0|     0|     0|     0|     0|     0|     5|     89|#99                   |
|       45|  3|2016-05-17 13:19:07 |    17|    7.0|       7.1|     2.3|    0.56|     5|     0|     0|    14|     5|     0|    24|    24|    14|     14|#AmeriCan             |
|       57|  4|2016-05-17 13:19:07 |     9|    4.9|       5.0|     3.1|    1.05|    30|     0|    13|     0|     0|     0|    30|    13|    13|      0|#Beings               |
|      120|  5|2016-05-17 13:19:07 |     6|    8.2|       8.3|     3.2|    1.32|    16|     0|     0|     0|     0|     0|     0|    16|     0|     68|#Help                 |
|      125|  6|2016-05-17 13:19:07 |  1198|    3.4|       3.9|     2.7|    0.08|    25|    15|    15|    15|     5|     5|     5|     5|     5|      5|#Horror               |


### movie_weekend_gross:


| movie_id| id|units | amount|locale | screens|end_date   | days_open|title           |
|--------:|--:|:-----|------:|:------|-------:|:----------|---------:|:---------------|
|   185421|  1|$     |   7806|USA    |       1|2001-12-09 |       147|Der blaue Engel |
|   185421|  2|$     |   1854|USA    |       1|2001-11-11 |       119|Der blaue Engel |
|   185421|  3|$     |   8134|USA    |       1|2001-11-04 |       112|Der blaue Engel |
|   185421|  4|$     |   3430|USA    |       1|2001-08-12 |        28|Der blaue Engel |
|   185421|  5|$     |   4808|USA    |       1|2001-07-22 |         7|Der blaue Engel |
|   185421|  6|$     |   6451|USA    |       1|2001-07-15 |         0|Der blaue Engel |

## Example usage

Here we use `dplyr` to connect to the database, and create a list of
the best 'underrated' movies of each year. The criteria are:

1. More than 500 ratings, but
1. fewer than 2000 ratings, and 
1. ranked via mean rating divided by standard deviation.



```r
library(RMySQL)
library(dplyr)
library(knitr)
imcon <- src_mysql(host='0.0.0.0',user='moe',password='movies4me',dbname='IMDB',port=23306)
dbGetQuery(imcon$con,'SET NAMES utf8')
```

```
## NULL
```

```r
tbl(imcon,'movie_votes') %>%
  filter(votes >= 500,votes <= 2000) %>% 
  inner_join(tbl(imcon,'movie_runtime') %>% 
    filter(runtime > 60) %>% 
    select(movie_id),by='movie_id') %>%
  mutate(vote_sr=vote_mean/vote_sd) %>%
  select(movie_id,vote_sr) %>%
  left_join(tbl(imcon,'title') %>% select(movie_id,title,production_year),by='movie_id') %>%
  arrange(desc(vote_sr)) %>%
  collect() %>% 
  group_by(production_year) %>%
  summarize(title=first(title),
    sr=max(vote_sr)) %>%
  ungroup() %>%
  arrange(production_year) %>%
  kable()
```



| production_year|title                                   |  sr|
|---------------:|:---------------------------------------|---:|
|            1930|The Doorway to Hell                     | 3.0|
|            1931|The Criminal Code                       | 3.3|
|            1932|American Madness                        | 3.1|
|            1933|The Story of Temple Drake               | 3.0|
|            1934|Housewife                               | 3.2|
|            1935|La kermesse héroïque                    | 3.0|
|            1936|The Trail of the Lonesome Pine          | 3.2|
|            1937|San Quentin                             | 3.0|
|            1938|Mysterious Mr. Moto                     | 3.2|
|            1939|Stanley and Livingstone                 | 3.6|
|            1940|The Invisible Man Returns               | 3.1|
|            1941|The Face Behind the Mask                | 3.0|
|            1942|Roxie Hart                              | 3.0|
|            1943|Madame Curie                            | 3.0|
|            1944|The Way Ahead                           | 3.0|
|            1945|The Way to the Stars                    | 3.0|
|            1946|I See a Dark Stranger                   | 3.0|
|            1947|The Web                                 | 3.6|
|            1948|Station West                            | 3.1|
|            1949|Shizukanaru kettô                       | 3.1|
|            1950|Woman on the Run                        | 3.1|
|            1951|Cry Danger                              | 3.1|
|            1952|The Steel Trap                          | 3.5|
|            1953|99 River Street                         | 3.1|
|            1954|Crime Wave                              | 3.1|
|            1955|The Girl in the Red Velvet Swing        | 3.4|
|            1956|Voici le temps des assassins...         | 3.5|
|            1957|Maya Bazaar                             | 3.3|
|            1958|Eroica                                  | 3.6|
|            1959|Princezna se zlatou hvezdou             | 3.2|
|            1960|Il vigile                               | 3.1|
|            1961|Cash on Demand                          | 3.4|
|            1962|Le signe du lion                        | 3.1|
|            1963|La cuisine au beurre                    | 3.4|
|            1964|Woh Kaun Thi?                           | 3.3|
|            1965|Etsuraku                                | 3.1|
|            1966|Ne nous fâchons pas                     | 3.4|
|            1967|I crudeli                               | 3.1|
|            1968|Il medico della mutua                   | 3.1|
|            1969|Zert                                    | 3.0|
|            1970|Jibon Thekey Neya                       | 3.9|
|            1971|Una farfalla con le ali insanguinate    | 3.6|
|            1972|Nagara Haavu                            | 3.7|
|            1973|Poszukiwany, poszukiwana                | 3.0|
|            1974|Jakob, der Lügner                       | 3.0|
|            1975|Olsen-banden på sporet                  | 3.4|
|            1976|Febbre da cavallo                       | 3.2|
|            1977|Lúdas Matyi                             | 3.3|
|            1978|Newsfront                               | 3.4|
|            1979|Shankarabharanam                        | 3.3|
|            1980|Varumayin Niram Sigappu                 | 3.2|
|            1981|Mathe paidi mou grammata                | 3.3|
|            1982|Namak Halaal                            | 3.0|
|            1983|Sagara Sangamam                         | 3.3|
|            1984|Ciske de Rat                            | 3.1|
|            1985|Marie                                   | 3.1|
|            1986|Hadashi no Gen 2                        | 3.2|
|            1987|Varázslat - Queen Budapesten            | 3.4|
|            1988|Oru CBI Diary Kurippu                   | 3.2|
|            1989|Mery per sempre                         | 3.1|
|            1990|Berkeley in the Sixties                 | 3.2|
|            1991|Sandesham                               | 3.7|
|            1992|Parenti serpenti                        | 3.0|
|            1993|Cuisine et dépendances                  | 3.0|
|            1994|Aguner Poroshmoni                       | 3.4|
|            1995|Om                                      | 3.2|
|            1996|Dipu Number 2                           | 3.6|
|            1997|Tutti giù per terra                     | 3.2|
|            1998|Meitantei Conan: 14 banme no target     | 3.2|
|            1999|André Hazes, zij gelooft in mij         | 3.1|
|            2000|Srabon Megher Din                       | 3.4|
|            2001|L'uomo in più                           | 3.1|
|            2002|Tiexi qu                                | 3.2|
|            2003|Ao no hono-o                            | 3.2|
|            2004|Plagues and Pleasures on the Salton Sea | 3.2|
|            2005|You're Gonna Miss Me                    | 3.3|
|            2006|The Battle of Chernobyl                 | 3.4|
|            2007|The English Surgeon                     | 3.4|
|            2008|Vox Populi                              | 3.1|
|            2009|La matassa                              | 3.4|
|            2010|Rubble Kings                            | 3.3|
|            2011|The Four Year Plan                      | 3.4|
|            2012|Radio Wars                              | 3.8|
|            2013|Filmage: The Story of Descendents/All   | 3.2|
|            2014|Prosper                                 | 3.7|
|            2015|Kendasampige                            | 3.7|
|            2016|Team Foxcatcher                         | 6.2|



