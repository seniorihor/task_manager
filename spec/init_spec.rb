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

  before do
    @user0 = User.create(login:     'login',
                         password:  'password',
                         firstname: 'firstname',
                         lastname:  'lastname',
                         token:     'auth_token')
    @user1 = User.create(login:     'user1',
                         password:  'password',
                         firstname: 'firstname',
                         lastname:  'lastname',
                         token:     'user1token')
    @user2 = User.create(login:     'user2',
                         password:  'password',
                         firstname: 'firstname',
                         lastname:  'lastname',
                         token:     'user2token')
  end

  def app
    Sinatra::Application
  end

  it 'logout should be successful' do
    request  = { taskmanager: { auth_token: @user0.token }}
    response = { logout: { error: 'Success' }}

    post '/protected/logout', request.to_json
    last_response.body.should == response.to_json
  end

  it 'login should be successful' do
    user     = User.first(login: @user0.login)

    request  = { taskmanager: { login:    user.login,
                                password: user.password }}
    response = { login: { error:      'Success',
                          auth_token: user.token,
                          friends:    user.friends }}

    post '/login', request.to_json
    last_response.body == response.to_json
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
    request  = { taskmanager: { auth_token: @user1.token }}
    response = { delete_user: { error: 'Success' }}

    post '/protected/delete_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'restore_user should be successful' do
    request  = { taskmanager: { auth_token: @user1.token }}
    response = { restore_user: { error: 'Success' }}

    post '/protected/restore_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'find_user should be successful' do
    request  = { taskmanager: { auth_token:   @user1.token,
                                search_value: @user2.login }}
    response = { find_user: { error: 'Success',
                              users: [{ login:     @user2.login,
                                        firstname: @user2.firstname,
                                        lastname:  @user2.lastname }]}}

    post '/protected/find_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'add_friend (invite) should be successful' do
    request  = { taskmanager: { auth_token:     @user1.token,
                                receiver_login: @user2.login,
                                priority:       4 }}
    response = { add_friend: { error: 'Success' }}

    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'add_friend (response) should be successful' do
    request  = { taskmanager: { auth_token:     @user2.token,
                                receiver_login: @user1.login,
                                friendship:     'true',
                                priority:       5 }}
    response = { add_friend: { error:     'Success',
                               login:     @user1.login,
                               firstname: @user1.firstname,
                               lastname:  @user1.lastname }}
    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'new_task should be successful' do
    request  = { taskmanager: { auth_token:     @user1.token,
                                receiver_login: @user2.login,
                                content:        'content',
                                priority:       rand(1..3) }}
    response = { new_task: { error: 'Success' }}

    post '/protected/new_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'get_task should be successful' do
    request  = { taskmanager: { auth_token: @user2.token }}
    response = { get_task: { error:    'Success',
                             quantity: 1,
                             tasks:    [{ id:         Task.last.id,
                                          content:    Task.last.content,
                                          priority:   Task.last.priority,
                                          user_login: @user1.login,
                                          created_at: Task.last.created_at.strftime('%d.%m.%Y %H:%M') }]}}

    post '/protected/get_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_task should be successful' do
    task_id  = Task.all(receiver_login: @user2.login).last(read: true).id
    request  = { taskmanager: { auth_token: @user2.token,
                                task_id:    task_id }}
    response = { delete_task: { error: 'Success' }}

    post '/protected/delete_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_friend should be successful' do
    request  = { taskmanager: { auth_token:     @user1.token,
                                receiver_login: @user2.login }}
    response = { delete_friend: { error: 'Success' }}

    post '/protected/delete_friend', request.to_json
    last_response.body.should == response.to_json
  end
end
