

# Bechdel test data

Here I use `dplyr` to gather data on films and gender from the IMDb mirror.
I drop movies within the `Documentary` genre, and only include those
which list English as one language.


```r
library(RMySQL)
library(dplyr)
library(knitr)
dbcon <- src_mysql(host='0.0.0.0',user='moe',password='movies4me',dbname='IMDB',port=23306)
capt <- dbGetQuery(dbcon$con,'SET NAMES utf8')

# genre information
movie_genres <- tbl(dbcon,'movie_info') %>%
	inner_join(tbl(dbcon,'info_type') %>% 
		filter(info %regexp% 'genres') %>%
		select(info_type_id),
		by='info_type_id') 
# get documentary movies;
doccos <- movie_genres %>% 
		filter(info %regexp% 'Documentary') %>%
		select(movie_id)
# language information
movie_languages <- tbl(dbcon,'movie_info') %>%
	inner_join(tbl(dbcon,'info_type') %>% 
		filter(info %regexp% 'languages') %>%
		select(info_type_id),
		by='info_type_id') 
# get movies with English
unnerstandit <- movie_languages %>% 
		filter(info %regexp% 'English') %>%
		select(movie_id)
# movies which are not documentaries, have some English, filtered by production year
movies <- tbl(dbcon,'title') %>%
	select(-imdb_index,-ttid,-md5sum) %>%
	anti_join(doccos %>% distinct(movie_id),by='movie_id') %>%
	inner_join(unnerstandit %>% distinct(movie_id),by='movie_id') %>%
	filter(production_year >= 1965,production_year <= 2015) %>%
	collect(n=Inf) 
```

Now I load information about people, selecting relationships where the person
is an actor or actress, director, writer, or producer of a film. I join the
gender and age information to the 'is in' relationship, and take sums
and weighted means, where the weighted means use a downweighting depending
on the `nr_order`.


```r
# change this to change downweighting.
# 3 = person #1 is twice as important as person #4
# 10 = person #1 is twice as important as person #11
ORDER_DOWNWEIGHTING <- 3.0
# acts/directs/writes/produces relation
# convert 'actress' and 'actor' to 'acts in' so that
# nr_order makes sense. 
# mariadb = awesome, BTW
raw_in <- tbl(dbcon,'cast_info') %>%
	inner_join(tbl(dbcon,'role_type') %>% 
		filter(role %regexp% 'actor|actress|producer|writer|director'),
		by='role_id') %>%
	select(person_id,movie_id,nr_order,role) %>%
	collect(n=Inf) %>%
	inner_join(movies %>% distinct(movie_id),by='movie_id') %>%
	mutate(role=as.factor(gsub('actor|actress','actsin',role)))
	#mutate(role=regexp_replace(role,'actor|actress','actsin')) 
# then coalesce nr_order to the maximal value.
max_order <- raw_in %>%
	group_by(movie_id,role) %>% 
	summarize(max_ord=pmin(1e4,max(coalesce(nr_order,0L),na.rm=TRUE))) %>%
	ungroup() 
	#summarize(max_ord=max(coalesce(nr_order,0))) %>%
# then coalesce nr_order to the maximal value.
is_in <- raw_in %>%
	inner_join(max_order,by=c('movie_id','role')) %>%
	mutate(nr_order=as.numeric(nr_order)) %>%
	mutate(nr_order=coalesce(nr_order,max_ord)) %>%
	mutate(weight=2^(-nr_order/ORDER_DOWNWEIGHTING)) %>%
	select(-nr_order,-max_ord)
	#mutate(nr_order=coalesce(nr_order,max_ord)) %>%
# get person data
person_data <- tbl(dbcon,'name') %>%
	select(person_id,name,gender,dob) %>%
	filter(!is.na(dob)) %>%
	filter(gender %regexp% 'm|f') %>%
  mutate(yob=year(dob)) %>%
	mutate(ismale=(gender=='m')) %>%
	filter(yob >= 1875) %>%
	collect(n=Inf) 
# merge person data and is-in data
merge_in <- is_in %>% 
	inner_join(person_data %>% select(person_id,yob,ismale),by='person_id') %>%
	inner_join(movies %>% distinct(movie_id,production_year),by='movie_id') %>%
	mutate(age=pmax(0,pmin(100,production_year - yob))) %>%
	select(-person_id,-production_year,-yob) %>%
	group_by(role,movie_id) %>%
	summarize(count=n(),
		count_male=sum(ismale),wsum_male=sum(ismale * weight),
		sum_age=sum(age),wsum_age=sum(age * weight),
		wsum=sum(weight)) %>%
	ungroup() %>%
	mutate(mean_male=count_male / count,
		wmean_male=wsum_male / wsum,
		mean_age=sum_age / count,
		wmean_age=wsum_age / wsum,
		count_female=count-count_male) %>%
	select(-wsum_male,-sum_age,-wsum_age,-wsum) %>%
	mutate(status=as.factor(ifelse(count_female==0,'all male',ifelse(count_male==0,'all female','mixed'))))
```

Now I get information about films: IMDb ratings (votes), and domestic gross box office.


```r
# votes for all movies, filtered by having enough votes
vote_info <- tbl(dbcon,'movie_votes') %>% 
	select(movie_id,votes,vote_mean,vote_sd) %>%
	filter(votes >= 20) %>%
	collect(n=Inf) %>%
	inner_join(movies %>% distinct(movie_id),by='movie_id') 
# US gross box office, in dollars. this is a view in the db
gross <- tbl(dbcon,'movie_US_gross') %>% 
	collect(n=Inf) %>%
	rename(theat_gross_dollars=gross_dollars) %>%
	rename(theat_last_date=last_report_date) %>%
	inner_join(movies %>% distinct(movie_id),by='movie_id') 
```

Now put them all together:

```r
movie_data <- movies %>%
	inner_join(vote_info,by='movie_id') %>%
	inner_join(gross,by='movie_id') %>%
	inner_join(merge_in,by='movie_id') 
```

Now take a look:


```r
movie_data %>% head(n=20) %>% kable()
```



| movie_id|title                 | production_year| votes| vote_mean| vote_sd| theat_gross_dollars|theat_last_date |role     | count| count_male| mean_male| wmean_male| mean_age| wmean_age| count_female|status     |
|--------:|:---------------------|---------------:|-----:|---------:|-------:|-------------------:|:---------------|:--------|-----:|----------:|---------:|----------:|--------:|---------:|------------:|:----------|
|      313|$9.99                 |            2008|  2634|       6.2|     2.3|             5.2e+04|2010-01-17      |actsin   |    11|          9|      0.82|       0.86|       46|        49|            2|mixed      |
|      313|$9.99                 |            2008|  2634|       6.2|     2.3|             5.2e+04|2010-01-17      |writer   |     2|          2|      1.00|       1.00|       41|        41|            0|all male   |
|      323|$pent                 |            2000|   107|       4.7|     2.5|             9.3e+03|2016-08-02      |actsin   |    16|         11|      0.69|       0.65|       40|        35|            5|mixed      |
|      323|$pent                 |            2000|   107|       4.7|     2.5|             9.3e+03|2016-08-02      |director |     1|          1|      1.00|       1.00|       31|        31|            0|all male   |
|      323|$pent                 |            2000|   107|       4.7|     2.5|             9.3e+03|2016-08-02      |writer   |     1|          1|      1.00|       1.00|       31|        31|            0|all male   |
|      362|'71                   |            2014| 33341|       6.4|     2.2|             1.3e+06|2015-05-03      |actsin   |    13|         11|      0.85|       0.99|       36|        28|            2|mixed      |
|      362|'71                   |            2014| 33341|       6.4|     2.2|             1.3e+06|2015-05-03      |director |     1|          1|      1.00|       1.00|       37|        37|            0|all male   |
|      412|'Breaker' Morant      |            1980| 10096|       7.1|     2.5|             7.1e+06|2016-08-02      |actsin   |    13|         13|      1.00|       1.00|       41|        42|            0|all male   |
|      412|'Breaker' Morant      |            1980| 10096|       7.1|     2.5|             7.1e+06|2016-08-02      |director |     1|          1|      1.00|       1.00|       40|        40|            0|all male   |
|      412|'Breaker' Morant      |            1980| 10096|       7.1|     2.5|             7.1e+06|2016-08-02      |writer   |     4|          4|      1.00|       1.00|       43|        40|            0|all male   |
|      447|'Crocodile' Dundee II |            1988| 43489|       5.5|     2.1|             1.1e+08|2016-08-02      |actsin   |    29|         24|      0.83|       0.76|       38|        42|            5|mixed      |
|      447|'Crocodile' Dundee II |            1988| 43489|       5.5|     2.1|             1.1e+08|2016-08-02      |director |     1|          1|      1.00|       1.00|       47|        47|            0|all male   |
|      447|'Crocodile' Dundee II |            1988| 43489|       5.5|     2.1|             1.1e+08|2016-08-02      |writer   |     2|          2|      1.00|       1.00|       49|        49|            0|all male   |
|      623|'night, Mother        |            1986|  1682|       7.2|     2.6|             4.4e+05|2016-08-02      |actsin   |     5|          1|      0.20|       0.12|       43|        43|            4|mixed      |
|      623|'night, Mother        |            1986|  1682|       7.2|     2.6|             4.4e+05|2016-08-02      |writer   |     2|          0|      0.00|       0.00|       39|        39|            2|all female |
|      665|'R Xmas               |            2001|  1021|       5.7|     2.2|             8.5e+02|2016-08-02      |actsin   |    14|          9|      0.64|       0.63|       35|        36|            5|mixed      |
|      665|'R Xmas               |            2001|  1021|       5.7|     2.2|             8.5e+02|2016-08-02      |director |     1|          1|      1.00|       1.00|       50|        50|            0|all male   |
|      665|'R Xmas               |            2001|  1021|       5.7|     2.2|             8.5e+02|2016-08-02      |writer   |     1|          1|      1.00|       1.00|       50|        50|            0|all male   |
|      678|'Round Midnight       |            1986|  3720|       6.9|     2.4|             3.3e+06|2016-08-02      |actsin   |    32|         27|      0.84|       0.67|       45|        45|            5|mixed      |
|      678|'Round Midnight       |            1986|  3720|       6.9|     2.4|             3.3e+06|2016-08-02      |director |     1|          1|      1.00|       1.00|       45|        45|            0|all male   |

## Bechdel test data

You can get this via their [API](http://bechdeltest.com/api/v1/doc#getMoviesByTitle). Get
rid of awful JSON with (awful) `jq`:


```bash
curl -o bechdel.json "http://bechdeltest.com/api/v1/getMoviesByTitle"
echo -e "id\timdbid\tyear\ttitle\trating" > bechdel.tsv
jq15 -r -s '.[] | .[] | [.id, .imdbid, .year, .title, .rating] | @tsv' bechdel.json >> bechdel.tsv
```

Join them together and save:


```r
upstream <- readr::read_tsv('bechdel.tsv')
# fix json problems
upstream <- upstream %>%
	rename(bechdel_id=id) %>%
	mutate(title=gsub('&amp;','&',title)) %>%
	mutate(title=gsub('&#39;',"'",title))

# string matching. fun!
library(stringdist)
twoway_key <- movie_data %>% 
	select(movie_id,title,production_year) %>%
	distinct(movie_id,.keep_all=TRUE) %>%
	mutate(ttl=phonetic(title)) %>%
	inner_join(upstream %>% mutate(ttl=phonetic(title)),by=c('ttl'='ttl','production_year'='year')) %>%
	mutate(titled=stringdist(title.x,title.y,method='jw')) %>%
	filter(titled < 0.1) %>%
	arrange(titled) %>%
	distinct(movie_id,.keep_all=TRUE) %>%
	arrange(desc(titled)) %>%
	select(movie_id,bechdel_id)

joined_data <- movie_data %>% inner_join(twoway_key,by='movie_id') %>%
	inner_join(upstream %>% rename(bechdel_title=title,bechdel_test=rating),by='bechdel_id')

# write it so you all can have it.
library(readr)
readr::write_csv(joined_data,path='bechdel_data.csv')
```

