
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

```
mkdir -p ./srv/imdb/mariadb ./srv/imdb/state ./srv/imdb/rw
chmod -R 777 ./srv/imdb
```

Then use `docker-compose` to initialize the database.

```
docker-compose build
docker-compose up -d
sleep 2s && docker-compose ps
```

It may take a while to pull the image for `mariadb`. To check on the status
of your images, run

```
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

```
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

```
# download:
imake -j 4 downloaded
# process 
imake -j 6 procd
# raw sqlite
imake raw_sqlite
# remove porn and so on:
imake sqlite
# stuff into mariadb:
imake put
```

Now connect to the database and poke around:

```
mysql -s --host=0.0.0.0 --port=23306 --user=moe --password=movies4me IMDB
```


