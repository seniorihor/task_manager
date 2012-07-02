require_relative '../init.rb'
require 'rack/test'
require 'json'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  DataMapper.finalize
  DataMapper.auto_migrate!
end

describe 'TaskManager' do

  def app
    Sinatra::Application
  end

  it 'should load login page' do

    post 'localhost:4567/login', { "taskmanager" => { "login" => "login", "password" => "password" }}.to_json
    response.status.should == 200
  end
end
