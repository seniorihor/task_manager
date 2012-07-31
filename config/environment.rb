require 'bundler'
Bundler.require

%w(datamapper
   ../models/user
   ../models/task
   ../models/friendship
   ../helpers/main
   ../routes/main).each { |file| require_relative file }
