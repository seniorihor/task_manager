# Configuration connection to database
configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/development.db")
end

configure :test do
  DataMapper.setup(:default, 'sqlite::memory:')
end

DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)
