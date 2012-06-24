source :rubygems

gem 'sinatra'
gem 'sinatra-reloader'
gem 'thin'
gem 'json'
gem 'dm-core'
gem 'dm-timestamps'
gem 'dm-validations'
gem 'dm-migrations'
gem 'dm-types'
gem 'dm-sqlite-adapter'
gem 'dm-postgres-adapter'
gem 'dm-serializer'

group :development do
  gem 'sqlite3'
  gem 'dm-sqlite-adapter'
end

group :test do
  gem 'sqlite3'
  gem 'rspec'
  gem 'rack'
  gem 'rack-test'
  gem 'autotest-growl'
  gem 'autotest-fsevent'
end

group :production do
  gem 'pg'
  gem 'dm-postgres-adapter'
end
