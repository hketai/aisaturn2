#!/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'

database_url = ENV['DATABASE_URL']

if database_url && !database_url.empty?
  uri = URI(database_url)
  host = uri.host
  port = uri.port
  username = uri.user
else
  host = ENV['POSTGRES_HOST']
  port = ENV['POSTGRES_PORT']
  username = ENV['POSTGRES_USERNAME']
end

host = 'postgres' if host.nil? || host.empty? || %w[localhost 127.0.0.1].include?(host)
port = '5432' if port.nil? || port.empty?
username = 'postgres' if username.nil? || username.empty?

puts "export POSTGRES_HOST=#{host} POSTGRES_PORT=#{port} POSTGRES_USERNAME=#{username}"
