#!/usr/bin/env ruby

require 'mongo'
require "net/http"
require "uri"
require 'yaml'
require 'bson'
require 'json'

config = YAML::load_file 'config.yaml'

unless config['mongo']['username'].nil?
  db = Mongo::Client.new(["#{config['mongo']['host']}:#{config['mongo']['port']}"],
                         :database => config['mongo']['db'])
else
  db = Mongo::Client.new(["#{config['mongo']['host']}:#{config['mongo']['port']}"],
                         :database => config['mongo']['db'],
                         :user => config['mongo']['username'],
                         :password => config['mongo']['password'])
end

db.database.collection_names
STDERR.puts "Connection to MongoDB: #{config['amqp']['host']} succeded"

db['events'].find.each do |event|

  STDERR.write "Sending event id = #{event['id']} "

  resp = Net::HTTP.new('localhost', '4567').start do |client|
    event.delete('_id')
    request                 = Net::HTTP::Post.new('/')
    request.body            = event.to_h.to_json
    request['Content-Type'] = 'application/json'

    client.request(request)
  end

  STDERR.puts "done (#{resp.code})"
end
