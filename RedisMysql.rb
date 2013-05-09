#!/usr/bin/env ruby

#
# # Example Class Usage
# rm = RedisMysql.new
# results = rm.query 'user_page_views:1', 10
#
# # debug
# puts results
#

require 'rubygems'
require 'redis'
require 'json'
require 'mysql2'

class RedisMysql

  def initialize
    @redis = Redis.new
    @mysql = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => 'PASSWORD', :database => 'redisgearman')
    @redis_results = []
  end

  def query(key, limit)
    @redis_results = query_redis key,limit
    return @redis_results if @redis_results.size >= limit

    @mysql_results = query_mysql key, (limit-@redis_results.size)
    @redis_results.concat @mysql_results

  end

  def query_redis(key, limit)
    results = @redis.lrange key, 0, limit
    return [] if results.nil?
    results.collect {|r| JSON.parse r}
  end

  def query_mysql(key, limit)

    # parse args
    parts = key.split ':'
    mysql_table = parts[0]
    user_id = parts[1]

    # get last timestamp from redis results
    last_timestamp = @redis_results.last['timestamp'] unless @redis_results.empty?

    where = []
    where << "user_id = '#{@mysql.escape user_id}'"
    where << "timestamp < '#{@mysql.escape last_timestamp}'" unless last_timestamp.nil?

    sql = "
      select *
      from user_page_views
      where #{where.join ' and '}
      order by id desc
      limit #{limit}"

    results = @mysql.query sql
    return [] if results.nil?
    results.collect {|r| r}

  end
end
