require_relative '../init.rb'
require 'rack/test'

set :environment, :test

def app
  Sinatra::Application
end

describe 'TaskManager' do
  include Rack::Test::Methods

  it 'should load login user' do
    get '/login'
    last_response.status.should == 200
  end
end
