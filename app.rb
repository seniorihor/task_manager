require 'data_mapper'
require 'json'
require 'sinatra'
require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'


class TaskManager < Sinatra::Application

  set :environment, ENV['RACK_ENV'] || :development
                                     #:test

# Configuration connection to database
configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/development.db")
  DataMapper::Logger.new($stdout, :debug)
end

configure :test do
  #DataMapper.setup(:default, "sqlite://#{Dir.pwd}/test.db")
  DataMapper.setup(:default, 'sqlite::memory:')
end

DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)
      
end


