require 'sinatra/base'

class TaskManager < Sinatra::Base
  set :environment, ENV['RACK_ENV'] || :development
                                       #:test

  require_relative '../config/environment'
  TaskManager.helpers CommonHelper
end
