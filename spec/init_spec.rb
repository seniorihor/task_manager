require_relative '../init.rb'
require 'rack/test'

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

  it 'should not load login page' do
    get '/login'
    last_response.status.should == 404
  end
end
