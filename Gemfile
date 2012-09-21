source :rubygems

# Project requirements
gem 'rake'
gem 'sinatra'

# Component requirements
gem 'dm-validations'
gem 'dm-timestamps'
gem 'dm-migrations'
gem 'dm-types'
gem 'dm-core'
gem 'json', '1.6.1'

group :development, :test do
  gem 'sqlite3'
  gem 'dm-sqlite-adapter'
  gem 'rspec'
  gem 'rack'
  gem 'rack-test'
end

group :production do
  gem 'pg'
  gem 'dm-postgres-adapter'
end
