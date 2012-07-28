require 'data_mapper'

# Configuration connection to database
configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/development.db")
  DataMapper::Logger.new($stdout, :debug)
end

configure :test do
  #DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/test.db")
  DataMapper.setup(:default, 'sqlite::memory:')
end

DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)


require_relative 'user'
require_relative 'task'
require_relative 'friendship'


DataMapper.finalize
DataMapper.auto_upgrade!