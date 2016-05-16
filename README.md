

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

Now connect to the database and poke around:


```bash
mysql -s --host=0.0.0.0 --port=23306 --user=moe --password=movies4me IMDB
```

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
imcon <- src_mysql(host = "0.0.0.0", user = "moe", 
    password = "movies4me", dbname = "IMDB", port = 23306)
dbGetQuery(imcon$con, "SET NAMES utf8")
```

```
## NULL
```

```r
tbl(imcon, "movie_votes") %>% filter(votes >= 500, 
    votes <= 2000) %>% mutate(vote_sr = vote_mean/vote_sd) %>% 
    select(movie_id, vote_sr) %>% left_join(tbl(imcon, 
    "title") %>% select(movie_id, title, production_year), 
    by = "movie_id") %>% arrange(desc(vote_sr)) %>% 
    collect() %>% group_by(production_year) %>% summarize(title = first(title), 
    sr = max(vote_sr)) %>% ungroup() %>% arrange(production_year) %>% 
    kable()
```



| production_year|title                                |  sr|
|---------------:|:------------------------------------|---:|
|            1930|The Doorway to Hell                  | 3.0|
|            1931|The Criminal Code                    | 3.3|
|            1932|Any Old Port!                        | 3.3|
|            1933|The Story of Temple Drake            | 3.0|
|            1934|Housewife                            | 3.2|
|            1935|The Fixer Uppers                     | 3.2|
|            1936|The Trail of the Lonesome Pine       | 3.2|
|            1937|San Quentin                          | 3.0|
|            1938|Boat Builders                        | 3.2|
|            1939|Stanley and Livingstone              | 3.6|
|            1940|The Invisible Man Returns            | 3.1|
|            1941|The Face Behind the Mask             | 3.0|
|            1942|Dog Trouble                          | 3.1|
|            1943|Madame Curie                         | 3.0|
|            1944|Puttin' on the Dog                   | 3.2|
|            1945|The Mouse Comes to Dinner            | 3.4|
|            1946|Trap Happy                           | 3.3|
|            1947|The Web                              | 3.6|
|            1948|Old Rockin' Chair Tom                | 3.3|
|            1949|Polka-Dot Puss                       | 3.2|
|            1950|Woman on the Run                     | 3.1|
|            1951|Ballot Box Bunny                     | 3.4|
|            1952|The Steel Trap                       | 3.5|
|            1953|99 River Street                      | 3.1|
|            1954|Crime Wave                           | 3.1|
|            1955|The Girl in the Red Velvet Swing     | 3.4|
|            1956|Voici le temps des assassins...      | 3.5|
|            1957|Maya Bazaar                          | 3.3|
|            1958|Eroica                               | 3.6|
|            1959|Princezna se zlatou hvezdou          | 3.2|
|            1960|Il vigile                            | 3.1|
|            1961|Cash on Demand                       | 3.4|
|            1962|Le signe du lion                     | 3.1|
|            1963|La cuisine au beurre                 | 3.4|
|            1964|Woh Kaun Thi?                        | 3.3|
|            1965|Vovka v Tridevyatom tsarstve         | 3.2|
|            1966|Ne nous fâchons pas                  | 3.4|
|            1967|Gutten som kappåt med trollet        | 3.2|
|            1968|Il medico della mutua                | 3.1|
|            1969|Zert                                 | 3.0|
|            1970|Jibon Thekey Neya                    | 3.9|
|            1971|Una farfalla con le ali insanguinate | 3.6|
|            1972|Nagara Haavu                         | 3.7|
|            1973|Poszukiwany, poszukiwana             | 3.0|
|            1974|Jakob, der Lügner                    | 3.0|
|            1975|Olsen-banden på sporet               | 3.4|
|            1976|Febbre da cavallo                    | 3.2|
|            1977|Lúdas Matyi                          | 3.3|
|            1978|Newsfront                            | 3.4|
|            1979|Shankarabharanam                     | 3.3|
|            1980|Varumayin Niram Sigappu              | 3.2|
|            1981|Mathe paidi mou grammata             | 3.3|
|            1982|Namak Halaal                         | 3.0|
|            1983|Sagara Sangamam                      | 3.3|
|            1984|Ciske de Rat                         | 3.1|
|            1985|Marie                                | 3.1|
|            1986|Hadashi no Gen 2                     | 3.2|
|            1987|Varázslat - Queen Budapesten         | 3.4|
|            1988|Pattana Pravesham                    | 3.6|
|            1989|Mery per sempre                      | 3.1|
|            1990|Berkeley in the Sixties              | 3.2|
|            1991|Sandesham                            | 3.7|
|            1992|Parenti serpenti                     | 3.0|
|            1993|Cuisine et dépendances               | 3.0|
|            1994|Aguner Poroshmoni                    | 3.4|
|            1995|Om                                   | 3.2|
|            1996|Dipu Number 2                        | 3.6|
|            1997|Tutti giù per terra                  | 3.2|
|            1998|Meitantei Conan: 14 banme no target  | 3.2|
|            1999|Simpan                               | 3.1|
|            2000|Srabon Megher Din                    | 3.4|
|            2001|L'uomo in più                        | 3.1|
|            2002|Tiexi qu                             | 3.2|
|            2003|Ao no hono-o                         | 3.2|
|            2004|Missing Sock                         | 3.3|
|            2005|Sunset Bollywood                     | 3.4|
|            2006|The Battle of Chernobyl              | 3.4|
|            2007|The English Surgeon                  | 3.4|
|            2008|Manjadikuru                          | 3.2|
|            2009|La matassa                           | 3.4|
|            2010|Ice Carosello                        | 3.7|
|            2011|Design the New Business              | 3.6|
|            2012|Radio Wars                           | 3.8|
|            2013|Noah                                 | 3.5|
|            2014|Prosper                              | 3.7|
|            2015|All the World in a Design School     | 5.1|
|            2016|Team Foxcatcher                      | 6.2|



