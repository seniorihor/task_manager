set :environment, ENV['RACK_ENV'] || :development
                                     #:test
root = ::File.dirname(__FILE__)
require ::File.join( root, 'app' )
run TaskManager.new
