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
    request  = { taskmanager: { auth_token: @user.token }}
    response = { logout: { error: 'Success' }}

    post '/protected/logout', request.to_json
    hash = to_hash(last_response.body)
    hash.to_json.should == response.to_json
  end

  it 'register should be successful' do
    request  = { taskmanager: { login:     'test',
                                password:  'password',
                                firstname: 'firstname',
                                lastname:  'lastname' }}
    response = { register: { error: 'Success' }}

    post '/register', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_user should be successful' do
    request  = { taskmanager: { auth_token: @user.token }}
    response = { delete_user: { error: 'Success' }}

    post '/protected/delete_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'restore_user should be successful' do
    request  = { taskmanager: { auth_token: @user.token }}
    response = { restore_user: { error: 'Success' }}

    post '/protected/restore_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'find_user should be successful' do
    request  = { taskmanager: { auth_token:   @user.token,
                                search_value: @user.login }}
    response = { find_user: { error: 'Success',
                              users: [{ login:     @user.login,
                                        firstname: @user.firstname,
                                        lastname:  @user.lastname }]}}

    post '/protected/find_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'add_friend (invite) should be successful' do
    request  = { taskmanager: { auth_token:     @user.token,
                                receiver_login: 'somebody',
                                content:        'greeting',
                                priority:       4 }}
    response = { add_friend: { error: 'Success' }}

    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'add_friend (response) should be successful' do
    request  = { taskmanager: { auth_token:     @user.token,
                                receiver_login: 'somebody',
                                content:        'true',
                                priority:       5 }}
    response = { add_friend: { error:      'Success',
                               friendship: true }}

    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_friend should be successful' do
    request  = { taskmanager: { auth_token:     @user.token,
                                receiver_login: 'somebody' }}
    response = { delete_friend: { error: 'Success' }}

    post '/protected/delete_friend', request.to_json
    last_response.body.should == response.to_json
  end
end


describe Task do

  before do
    @user = User.create(login: 'login', password: 'password', firstname: 'firstname', lastname: 'lastname', token: 'auth_token')
  end

  def app
    Sinatra::Application
  end

  def to_hash(json_data)
    JSON.parse(json_data)
  end

  it 'new_task should be successful' do
    request  = { taskmanager: { auth_token:     @user.token,
                                receiver_login: 'somebody',
                                content:        'content',
                                priority:       rand(1..3) }}
    response = { new_task: { error: 'Success' }}

    post '/protected/new_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_task should be successful' do
    task_id  = Task.all(receiver_login: @user.login).last(read: false).id
    request  = { taskmanager: { auth_token: @user.token,
                                task_id:    task_id }}
    response = { delete_task: { error: 'Success' }}

    post '/protected/delete_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'get_task should be successful' do
    request  = { taskmanager: { auth_token: @user.token }}
    response = { get_task: { error: 'Success' }}

    post '/protected/get_task', request.to_json
    last_response.body.should == response.to_json
  end
end
