#!/usr/bin/env ruby

require 'rubygems'
require 'gearman'
require 'json'

servers = ['localhost']
client = Gearman::Client.new(servers)
taskset = Gearman::TaskSet.new(client)

data = '{"user_id":1,"timestamp":"2013-02-14 19:13:15","page":"http://www.google.com"}'

result = client.do_task('redis_worker', data)
puts result
