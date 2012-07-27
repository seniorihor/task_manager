source :rubygems

# Server requirements
# gem 'thin' # or mongrel
# gem 'trinidad', :platform => 'jruby'

# Project requirements
gem 'rake'
gem 'sinatra'
#gem 'sinatra-flash', :require => 'sinatra/flash'

# Component requirements
gem 'dm-sqlite-adapter'
gem 'dm-validations'
gem 'dm-timestamps'
gem 'dm-migrations'
#gem 'dm-constraints'
#gem 'dm-aggregates'
#gem 'dm-types'
gem 'dm-core'
gem 'json'

group :development, :test do
  gem 'sqlite3'
  gem 'rspec'
  gem 'rack'
  gem 'rack-test'
  #gem 'autotest-growl'
  #gem 'autotest-fsevent'
end

group :production do
  gem 'pg'
  gem 'dm-postgres-adapter'
end

# Test requirements

# Padrino Stable Gem
gem 'padrino'#, '0.10.7'

# Or Padrino Edge
# gem 'padrino', :git => 'git://github.com/padrino/padrino-framework.git'

# Or Individual Gems
# %w(core gen helpers cache mailer admin).each do |g|
#   gem 'padrino-' + g, '0.10.7'
# end
