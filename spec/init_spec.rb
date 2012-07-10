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

  it 'register user1 should be successful' do
    request  = { taskmanager: { login:     'login1',
                                password:  'password1',
                                firstname: 'firstname1',
                                lastname:  'lastname1' }}
    post '/register', request.to_json

    response = { register: { error: 'Success' }}
    last_response.body.should == response.to_json
  end

  it 'register user2 should be successful' do
    request  = { taskmanager: { login:     'login2',
                                password:  'password2',
                                firstname: 'firstname2',
                                lastname:  'lastname2' }}
    post '/register', request.to_json

    response = { register: { error: 'Success' }}
    last_response.body.should == response.to_json
  end

  it 'login user1 should be successful' do
    request  = { taskmanager: { login:    User.first.login,
                                password: User.first.password }}
    post '/login', request.to_json

    response = { login: { error:      'Success',
                          auth_token: User.first.token,
                          friends:    User.first.friends }}
    last_response.body.should == response.to_json
  end

  it 'login user1 again should be successful' do
    request  = { taskmanager: { login:    User.first.login,
                                password: User.first.password }}
    post '/login', request.to_json

    response = { login: { error: 'Already in system' }}
    last_response.body.should == response.to_json
  end

  it 'login user2 should be successful' do
    request  = { taskmanager: { login:    User.last.login,
                                password: User.last.password }}
    post '/login', request.to_json

    response = { login: { error:      'Success',
                          auth_token: User.last.token,
                          friends:    User.last.friends }}
    last_response.body.should == response.to_json
  end

  it 'logout user1 should be successful' do
    request  = { taskmanager: { auth_token: User.first.token }}
    post '/protected/logout', request.to_json

    response = { logout: { error: 'Success' }}
    last_response.body.should == response.to_json
  end

  it 'login user1 should be successful' do
    request  = { taskmanager: { login:    User.first.login,
                                password: User.first.password }}
    post '/login', request.to_json

    response = { login: { error:      'Success',
                          auth_token: User.first.token,
                          friends:    User.first.friends }}
    last_response.body.should == response.to_json
  end

  it 'delete user1 should be successful' do
    request  = { taskmanager: { auth_token: User.first.token }}
    response = { delete_user: { error: 'Success' }}

    post '/protected/delete_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'restore user1 should be successful' do
    request  = { taskmanager: { auth_token: User.first.token }}
    response = { restore_user: { error: 'Success' }}

    post '/protected/restore_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'find user2 should be successful' do
    request  = { taskmanager: { auth_token:   User.first.token,
                                search_value: User.last.login }}
    response = { find_user: { error: 'Success',
                              users: [{ login:     User.last.login,
                                        firstname: User.last.firstname,
                                        lastname:  User.last.lastname }]}}

    post '/protected/find_user', request.to_json
    last_response.body.should == response.to_json
  end

  it 'invite to friends user2 should be successful' do
    request  = { taskmanager: { auth_token:     User.first.token,
                                receiver_login: User.last.login,
                                priority:       4 }}
    response = { add_friend: { error: 'Success' }}

    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'response on invite from user2 to user1 should be successful' do
    request  = { taskmanager: { auth_token:     User.last.token,
                                receiver_login: User.first.login,
                                friendship:     'true',
                                priority:       5 }}
    response = { add_friend: { error:     'Success',
                               login:     User.first.login,
                               firstname: User.first.firstname,
                               lastname:  User.first.lastname }}
    post '/protected/add_friend', request.to_json
    last_response.body.should == response.to_json
  end

  it 'new_task to user2 should be successful' do
    request  = { taskmanager: { auth_token:     User.first.token,
                                receiver_login: User.last.login,
                                content:        'content',
                                priority:       rand(1..3) }}
    response = { new_task: { error: 'Success' }}

    post '/protected/new_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'get_task user2 should be successful' do
    request  = { taskmanager: { auth_token: User.last.token }}
    response = { get_task: { error:    'Success',
                             quantity: Task.all(receiver_login: User.last.login, read: false).size,
                             tasks:    [{ id:         Task.last(receiver_login: User.last.login).id,
                                          content:    Task.last(receiver_login: User.last.login).content,
                                          priority:   Task.last(receiver_login: User.last.login).priority,
                                          user_login: User.first.login,
                                          created_at: Task.last(receiver_login: User.last.login).created_at.strftime('%d.%m.%Y %H:%M') }]}}

    post '/protected/get_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_task should be successful' do
    task_id  = Task.all(receiver_login: User.last.login).last(read: true).id
    request  = { taskmanager: { auth_token: User.last.token,
                                task_id:    task_id }}
    response = { delete_task: { error: 'Success' }}

    post '/protected/delete_task', request.to_json
    last_response.body.should == response.to_json
  end

  it 'delete_friend should be successful' do
    request  = { taskmanager: { auth_token:     User.first.token,
                                receiver_login: User.last.login }}
    response = { delete_friend: { error: 'Success' }}

    post '/protected/delete_friend', request.to_json
    last_response.body.should == response.to_json
  end
end
