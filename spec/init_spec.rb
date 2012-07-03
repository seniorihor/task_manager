require_relative '../init.rb'
require 'rack/test'
require 'json'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  DataMapper.finalize
  DataMapper.auto_migrate!
end


describe User do

  before do
    @user = User.create(login: 'login', password: 'password', firstname: 'firstname', lastname: 'lastname', token: 'auth_token')
  end

  def app
    Sinatra::Application
  end

  def to_hash(json_data)
    JSON.parse(json_data)
  end

  it 'login should be successful' do
    request  = { taskmanager: { login:    @user.login,
                                password: @user.password }}
    response = { login: { error:      'Success',
                          auth_token: @user.token,
                          friends:    @user.friends }}

    post '/login', request.to_json
    hash = to_hash(last_response.body)
    hash['login']['auth_token'] = 'auth_token'
    hash.to_json.should == response.to_json
  end

  it 'logout should be successful' do
    puts "token: #{@user.token}"

    request  = { taskmanager: { auth_token: @user.token }}
    response = { logout: { error: 'Success' }}

    post '/protected/logout', request.to_json
    hash = to_hash(last_response.body)
    hash.to_json.should == response.to_json
  end

  it 'register should be successful' do
    request  = { taskmanager: { login: 'test', password: 'password', firstname: 'firstname', lastname: 'lastname' }}
    response = { register: { error: 'Success' }}
    post '/register', request.to_json
    last_response.body.should == response.to_json
  end
end
