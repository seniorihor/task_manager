require 'sinatra'

class TaskManager < Sinatra::Application
  set :environment, ENV['RACK_ENV'] || :development
                                       #:test
end

require_relative 'config/init'
require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'
