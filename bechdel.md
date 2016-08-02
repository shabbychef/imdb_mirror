

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
	collect()
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
	collect() %>%
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
	collect()
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
	collect() %>%
	inner_join(movies %>% distinct(movie_id),by='movie_id') 
# US gross box office, in dollars. this is a view in the db
gross <- tbl(dbcon,'movie_US_gross') %>% 
	collect() %>%
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



| movie_id|title                   | production_year.x|  votes| vote_mean| vote_sd| vote_se| gross_dollars|last_report_date | person_id| nr_order|role   | max_ord| weight|  yob| ismale| production_year.y| age| count| sum_male| wsum_male| sum_age| wsum_age| wsum| mean_male| wmean_male| mean_age| wmean_age| sum_female|
|--------:|:-----------------------|-----------------:|------:|---------:|-------:|-------:|-------------:|:----------------|---------:|--------:|:------|-------:|------:|----:|------:|-----------------:|---:|-----:|--------:|---------:|-------:|--------:|----:|---------:|----------:|--------:|---------:|----------:|
|      323|$pent                   |              2000|    107|       4.7|     2.5|    0.24|       9.3e+03|2016-08-02       |     83999|        6|actsin |       6|   0.25| 1963|      1|              2000|   0|     1|        1|      0.25|       0|        0| 0.25|         1|          1|        0|         0|          0|
|      447|'Crocodile' Dundee II   |              1988|  43489|       5.5|     2.1|    0.01|       1.1e+08|2016-08-02       |     34738|       39|actsin |      56|   0.00| 1964|      1|              1988|   0|     3|        3|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|      447|'Crocodile' Dundee II   |              1988|  43489|       5.5|     2.1|    0.01|       1.1e+08|2016-08-02       |     62626|       46|actsin |      56|   0.00| 1951|      1|              1988|   0|     3|        3|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|      447|'Crocodile' Dundee II   |              1988|  43489|       5.5|     2.1|    0.01|       1.1e+08|2016-08-02       |     87312|       56|actsin |      56|   0.00| 1918|      1|              1988|   0|     3|        3|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|      665|'R Xmas                 |              2001|   1021|       5.7|     2.2|    0.07|       8.5e+02|2016-08-02       |     78116|        5|actsin |      44|   0.31| 1934|      1|              2001|   0|     1|        1|      0.31|       0|        0| 0.31|         1|          1|        0|         0|          0|
|      774|'Til There Was You      |              1997|   2299|       5.3|     2.3|    0.05|       3.5e+06|1997-08-03       |      8925|       NA|actsin |      31|     NA| 1946|      1|              1997|   0|     2|        2|        NA|       0|       NA|   NA|         1|         NA|        0|        NA|          0|
|      774|'Til There Was You      |              1997|   2299|       5.3|     2.3|    0.05|       3.5e+06|1997-08-03       |     68853|       31|actsin |      31|   0.00| 1958|      1|              1997|   0|     2|        2|        NA|       0|       NA|   NA|         1|         NA|        0|        NA|          0|
|      845|(500) Days of Summer    |              2009| 369188|       7.0|     2.4|    0.00|       3.2e+07|2009-11-22       |     77519|        3|actsin |      27|   0.50| 1978|      1|              2009|   0|     1|        1|      0.50|       0|        0| 0.50|         1|          1|        0|         0|          0|
|     1046|*batteries not included |              1987|  22871|       6.0|     2.1|    0.01|       3.3e+07|2016-08-02       |     32536|        7|actsin |      30|   0.20| 1928|      1|              1987|   0|     2|        2|      0.20|       0|        0| 0.20|         1|          1|        0|         0|          0|
|     1046|*batteries not included |              1987|  22871|       6.0|     2.1|    0.01|       3.3e+07|2016-08-02       |     75876|       30|actsin |      30|   0.00| 1929|      1|              1987|   0|     2|        2|      0.20|       0|        0| 0.20|         1|          1|        0|         0|          0|
|     1135|...and justice for all. |              1979|  22514|       6.9|     2.3|    0.02|       3.3e+07|1979-12-31       |     60458|       24|actsin |      35|   0.00| 1920|      1|              1979|   0|     3|        3|      0.05|       0|        0| 0.05|         1|          1|        0|         0|          0|
|     1135|...and justice for all. |              1979|  22514|       6.9|     2.3|    0.02|       3.3e+07|1979-12-31       |     73229|       35|actsin |      35|   0.00| 1948|      1|              1979|   0|     3|        3|      0.05|       0|        0| 0.05|         1|          1|        0|         0|          0|
|     1135|...and justice for all. |              1979|  22514|       6.9|     2.3|    0.02|       3.3e+07|1979-12-31       |     83022|       13|actsin |      35|   0.05| 1936|      1|              1979|   0|     3|        3|      0.05|       0|        0| 0.05|         1|          1|        0|         0|          0|
|     1848|10                      |              1979|  12055|       6.0|     2.1|    0.02|       7.5e+07|2016-08-02       |     12052|       NA|actsin |      37|     NA| 1949|      1|              1979|   0|     2|        2|        NA|       0|       NA|   NA|         1|         NA|        0|        NA|          0|
|     1848|10                      |              1979|  12055|       6.0|     2.1|    0.02|       7.5e+07|2016-08-02       |     47124|       16|actsin |      37|   0.02| 1941|      1|              1979|   0|     2|        2|        NA|       0|       NA|   NA|         1|         NA|        0|        NA|          0|
|     2016|10 to Midnight          |              1983|   4261|       6.0|     2.1|    0.03|       7.1e+06|2016-08-02       |     14393|       33|actsin |      33|   0.00| 1932|      1|              1983|   0|     1|        1|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|     2027|10 Years                |              2011|  18048|       6.0|     2.1|    0.02|       2.0e+05|2013-05-30       |     63326|       44|actsin |      44|   0.00| 1964|      1|              2011|   0|     1|        1|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|     2105|100 Bloody Acres        |              2012|   2552|       6.0|     2.1|    0.04|       6.2e+03|2013-09-01       |      9371|        4|actsin |       4|   0.40| 1979|      1|              2012|   0|     1|        1|      0.40|       0|        0| 0.40|         1|          1|        0|         0|          0|
|     2371|101 Reykjavík           |              2000|   8159|       6.4|     2.2|    0.02|       1.2e+04|2001-07-29       |     80088|       28|actsin |      28|   0.00| 1978|      1|              2000|   0|     1|        1|      0.00|       0|        0| 0.00|         1|          1|        0|         0|          0|
|     2671|12 and Holding          |              2005|   6071|       7.0|     2.4|    0.03|       9.6e+04|2006-07-16       |     46847|       17|actsin |      17|   0.02| 1955|      1|              2005|   0|     1|        1|      0.02|       0|        0| 0.02|         1|          1|        0|         0|          0|

```r
# write it so you all can have it.
library(readr)
readr::write_csv(movie_data,path='bechdel_data.csv')
```

have to tidy them.
