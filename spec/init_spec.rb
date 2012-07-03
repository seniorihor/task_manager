require_relative '../init.rb'
require 'rack/test'
require 'rspec'
require 'json'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  DataMapper.finalize
  DataMapper.auto_migrate!
end

describe User do

  def app
    Sinatra::Application
  end

  it 'should get a failed response to login' do

    request  = { "taskmanager" => { "login" => "login", "password" => "password" }}
    response = { "login" => { "error" => "Invalid login or password" }}

    post '/login', request.to_json
    last_response.body.should == response.to_json
  end
end
