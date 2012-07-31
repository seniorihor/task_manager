require 'sinatra'

class TaskManager < Sinatra::Application
  set :environment, ENV['RACK_ENV'] || :development
                                       #:test
  require_relative 'config/environment'
  TaskManager.helpers CommonHelper
end

