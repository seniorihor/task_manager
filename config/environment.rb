require 'bundler'
Bundler.require

%w(data_mapper_conf
   ../models/user
   ../models/task
   ../models/friendship
   ../helpers/main
   ../routes/main).each { |file| require_relative file }
