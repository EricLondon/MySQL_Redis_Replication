
# upgrade packages
apt-get update
apt-get upgrade -y

# install ssh server
apt-get install openssh-server -y

# installed Mysql Server
apt-get install mysql-server -y

##################################################
# install Ruby via RVM

curl -L https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
# "rvm requirements" yields:
apt-get --no-install-recommends install build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev libgdbm-dev ncurses-dev automake libtool bison subversion pkg-config libffi-dev
rvm install ruby

##################################################
# install Redis

apt-get install tcl8.5 -y
wget http://redis.googlecode.com/files/redis-2.6.9.tar.gz
tar -xzf redis-2.6.9.tar.gz
cd redis-2.6.9
make
make test
cd src
cp redis-benchmark redis-check-aof redis-check-dump redis-cli redis-sentinel redis-server /usr/local/bin/
cd ..
cp redis.conf /etc

# start redis
redis-server /etc/redis.conf &

# test redis
redis-cli ping
PONG

##################################################
# install Gearman
apt-get install gearman gearman-server -y

# check if service is running
/etc/init.d/gearman-job-server status
 * gearmand is running

##################################################
# Installed MySQL JSON UDF

apt-get install libmysqlclient-dev -y
cd
mkdir ~/lib_mysqludf_json
cd ~/lib_mysqludf_json
wget http://www.mysqludf.org/lib_mysqludf_json/lib_mysqludf_json_0.0.2.tar.gz
tar -xzf lib_mysqludf_json_0.0.2.tar.gz

# remove shared object, and recompile
rm lib_mysqludf_json.so
gcc $(mysql_config --cflags) -shared -fPIC -o lib_mysqludf_json.so lib_mysqludf_json.c

# locate plugin directory
mysql -u root -pPASSWORD --execute="show variables like '%plugin%';"
+---------------+------------------------+
| Variable_name | Value                  |
+---------------+------------------------+
| plugin_dir    | /usr/lib/mysql/plugin/ |
+---------------+------------------------+

# copy shared object to plugin directory
cp lib_mysqludf_json.so /usr/lib/mysql/plugin/

# enable json_object method
mysql -u root -pPASSWORD --execute="create function json_object returns string soname 'lib_mysqludf_json.so'"

##################################################
# Installed MySQL Gearman UDF

apt-get install libgearman-dev -y
cd
wget https://launchpad.net/gearman-mysql-udf/trunk/0.6/+download/gearman-mysql-udf-0.6.tar.gz
tar -xzf gearman-mysql-udf-0.6.tar.gz
cd gearman-mysql-udf-0.6
./configure --with-mysql=/usr/bin/mysql_config --libdir=/usr/lib/mysql/plugin/
make
make install

# enabled udf functions
mysql -u root -pPASSWORD --execute="CREATE FUNCTION gman_do_background RETURNS STRING SONAME 'libgearman_mysql_udf.so'"
mysql -u root -pPASSWORD --execute="CREATE FUNCTION gman_servers_set RETURNS STRING SONAME 'libgearman_mysql_udf.so'"

# set gearman server
mysql -u root -pPASSWORD --execute="SELECT gman_servers_set('127.0.0.1')"

##################################################

# setup RVM gemset
mkdir ~/ruby
echo "rvm use --create ruby-1.9.3@redis_gearman" > ~/ruby/.rvmrc
cd ~/ruby

##################################################
# Testing Gearman worker & Redis

# in terminal 1, start worker
./redis_worker.rb

# in terminal 2, check gearman status & verify worker
(echo status ; sleep 0.1) | netcat 127.0.0.1 4730
redis_worker	0	0	1

# in terminal 3, monitor redis
redis-cli monitor
OK

# in terminal 4, run client test script
./redis_client.rb
true

# in terminal 3, verify redis lpush:
redis-cli monitor
OK
1361012555.700504 [0 127.0.0.1:34135] "lpush" "user_page_views:1" "{\"user_id\":1,\"timestamp\":\"2013-02-14 19:13:15\",\"page\":\"http://www.google.com\"}"

##################################################
# MySQL data setup

# add database & table
mysql -u root -pPASSWORD
mysql> create database redisgearman;
mysql> use redisgearman;
mysql> CREATE TABLE `user_page_views` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `page` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
mysql> exit

# add test record
mysql -u root -pPASSWORD redisgearman --execute="insert into user_page_views (user_id, page) values (1, 'http://www.google.com')"

# ensure json udf is working
mysql -u root -pPASSWORD redisgearman --execute="select json_object(user_id as \`user_id\`, timestamp as \`timestamp\`, page as \`page\`) as json from user_page_views"
+--------------------------------------------------------------------------------+
| json                                                                           |
+--------------------------------------------------------------------------------+
| {"user_id":1,"timestamp":"2013-02-14 19:13:15","page":"http://www.google.com"} |
+--------------------------------------------------------------------------------+

# enable trigger
mysql -u root -pPASSWORD redisgearman < ~/trigger.sql

##################################################
# Trigger + Gearman worker + Redis test

# example insert statement
insert into user_page_views (user_id, page) values (1, 'http://ericlondon.com/recent-posts');

# mysql insert => mysql trigger => gearman udf => ruby redis worker => redis insert..

# output from redis-cli monitor
redis-cli monitor
OK
1361327500.888805 [0 127.0.0.1:33649] "lpush" "user_page_views:1" "{\"user_id\":1,\"timestamp\":\"2013-02-19 21:31:40\",\"page\":\"http://ericlondon.com/recent-posts\"}"

##################################################



