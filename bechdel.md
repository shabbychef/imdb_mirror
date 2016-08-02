

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
	summarize(max_ord=max(pmax(0,nr_order),na.rm=TRUE)) %>%
	ungroup() 
	#summarize(max_ord=max(coalesce(nr_order,0))) %>%
# then coalesce nr_order to the maximal value.
is_in <- raw_in %>%
	inner_join(max_order,by=c('movie_id','role')) %>%
	mutate(nr_order=as.numeric(pmin(nr_order,max_ord))) %>%
	mutate(weight=2^(-nr_order/ORDER_DOWNWEIGHTING)) 
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
	mutate(age=max(0,min(100,production_year - yob))) %>%
	group_by(role,movie_id) %>%
	mutate(count=n(),
		sum_male=sum(ismale),wsum_male=sum(ismale * weight),
		sum_age=sum(age),wsum_age=sum(age * weight),
		wsum=sum(weight)) %>%
	ungroup() %>%
	mutate(mean_male=sum_male / count,
		wmean_male=wsum_male / wsum,
		mean_age=sum_age / count,
		wmean_age=wsum_age / wsum,
		sum_female=count-sum_male) 
```

Now I get information about films: IMDb ratings (votes), and domestic gross box office.


```r
# votes for all movies, filtered by having enough votes
vote_info <- tbl(dbcon,'movie_votes') %>% 
	select(movie_id,votes,vote_mean,vote_sd,vote_se) %>%
	filter(votes >= 20) %>%
	collect(n=Inf) %>%
	inner_join(movies %>% distinct(movie_id),by='movie_id') 
# US gross box office, in dollars. this is a view in the db
gross <- tbl(dbcon,'movie_US_gross') %>% 
	collect(n=Inf) %>%
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



| movie_id|title | production_year.x| votes| vote_mean| vote_sd| vote_se| gross_dollars|last_report_date | person_id| nr_order|role   | max_ord| weight|  yob| ismale| production_year.y| age| count| sum_male| wsum_male| sum_age| wsum_age| wsum| mean_male| wmean_male| mean_age| wmean_age| sum_female|
|--------:|:-----|-----------------:|-----:|---------:|-------:|-------:|-------------:|:----------------|---------:|--------:|:------|-------:|------:|----:|------:|-----------------:|---:|-----:|--------:|---------:|-------:|--------:|----:|---------:|----------:|--------:|---------:|----------:|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |    194917|       11|actsin |      21|   0.08| 1947|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |    194917|       11|actsin |      21|   0.08| 1947|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |    280734|       14|actsin |      21|   0.04| 1982|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |    595022|        5|actsin |      21|   0.31| 1974|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1187183|        2|actsin |      21|   0.63| 1959|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1406077|        7|actsin |      21|   0.20| 1969|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1595123|        4|actsin |      21|   0.40| 1941|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1653154|       19|actsin |      21|   0.01| 1959|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1840150|        1|actsin |      21|   0.79| 1951|      1|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   2955050|        6|actsin |      21|   0.25| 1972|      0|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   3606591|        8|actsin |      21|   0.16| 1979|      0|              2008|   0|    11|        9|       2.5|       0|        0|    3|      0.82|       0.86|        0|         0|          2|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1092814|       NA|writer |    -Inf|     NA| 1967|      1|              2008|   0|     2|        2|        NA|       0|       NA|   NA|      1.00|         NA|        0|        NA|          0|
|      313|$9.99 |              2008|  2634|       6.2|     2.3|    0.05|         52107|2010-01-17       |   1092814|       NA|writer |    -Inf|     NA| 1967|      1|              2008|   0|     2|        2|        NA|       0|       NA|   NA|      1.00|         NA|        0|        NA|          0|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |     83999|        6|actsin |      23|   0.25| 1963|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |    208620|       NA|actsin |      23|     NA| 1975|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |    346335|       16|actsin |      23|   0.02| 1969|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |    346376|        8|actsin |      23|   0.16| 1934|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |   1232394|        3|actsin |      23|   0.50| 1968|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |   1258453|        1|actsin |      23|   0.79| 1972|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|
|      323|$pent |              2000|   107|       4.7|     2.5|    0.24|          9287|2016-08-02       |   1469036|       20|actsin |      23|   0.01| 1959|      1|              2000|   0|    16|       11|        NA|       0|       NA|   NA|      0.69|         NA|        0|        NA|          5|

```r
# write it so you all can have it.
library(readr)
readr::write_csv(movie_data,path='bechdel_data.csv')
```

have to tidy them.