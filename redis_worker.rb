#!/usr/bin/env ruby

require 'rubygems'
require 'gearman'
require 'redis'
require 'json'

servers = ['localhost']
worker = Gearman::Worker.new(servers)

REDIS_DELIMITER = ':'
$redis = Redis.new

module RedisWorker
  def RedisWorker.work(data, job)

    # decode json
    json_data = JSON.parse data

    # create redis key
    redis_key = "user_page_views#{REDIS_DELIMITER}#{json_data['user_id']}"

    $redis.lpush redis_key, data

    true
  end
end

worker.add_ability('redis_worker') do |data,job|
  RedisWorker::work data,job
end

loop {worker.work}
