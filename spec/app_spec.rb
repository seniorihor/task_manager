require_relative '../app/app.rb'
require 'rack/test'
require 'json'
require 'padrino'

set :environment, :test


RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  DataMapper.finalize
  DataMapper.auto_migrate!
end


describe 'TaskManager' do

  before(:each) do
    User.create( login:     'login1',
                 password:  'password1',
                 firstname: 'firstname1',
                 lastname:  'lastname1',
                 token:     'user1token')

    User.create( login:     'login2',
                 password:  'password2',
                 firstname: 'firstname2',
                 lastname:  'lastname2',
                 token:     'user2token')
  end

  def app
    Sinatra::Application
  end

  context 'register' do
    it 'of user1 should be successful' do
      request  = { taskmanager: { login:     'login',
                                  password:  'password',
                                  firstname: 'firstname',
                                  lastname:  'lastname' }}
      post '/register', request.to_json

      response = { register: { error: 'Success' }}
      last_response.body.should == response.to_json
    end

    it 'of user2 shouldn\'t be successful' do
      request  = { taskmanager: { login:     '',
                                  password:  'password2',
                                  firstname: 'firstname2',
                                  lastname:  'lastname2' }}
      post '/register', request.to_json

      response = { register: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

    it 'of user2 shouldn\'t be successful because of already existing login' do
      request  = { taskmanager: { login:     'login1',
                                  password:  'password2',
                                  firstname: 'firstname2',
                                  lastname:  'lastname2' }}
      post '/register', request.to_json

      response = { register: { error: 'Login exists' }}
      last_response.body.should == response.to_json
    end

    it 'of user2 shouldn\'t be successful because of validation' do
      request  = { taskmanager: { login:     'l',
                                  password:  'password2',
                                  firstname: 'firstname2',
                                  lastname:  'lastname2' }}
      post '/register', request.to_json

      response = { register: { error: 'Failure' }}
      last_response.body.should == response.to_json
    end

    after(:all) do
      User.last.destroy!
    end

  end

  context 'login' do
    it 'of user1 should be successful' do
      User.first.update(token: nil)
      request  = { taskmanager: { login:    User.first.login,
                                  password: User.first.password }}
      post '/login', request.to_json

      response = { login: { error:      'Success',
                            auth_token: User.first.token,
                            friends:    User.first.friends.to_a }}

      last_response.body.should == response.to_json
    end

    it 'of user1 again should be failure' do
      request  = { taskmanager: { login:    User.first.login,
                                  password: User.first.password }}
      post '/login', request.to_json

      response = { login: { error: 'Already in system' }}

      last_response.body.should == response.to_json
    end

    it 'of user2 shouldn\'t be successful' do
      request  = { taskmanager: { login:    'Invalid login',
                                  password: User.last.password }}
      post '/login', request.to_json

      response = { login: { error: 'Invalid login or password' }}

      last_response.body.should == response.to_json
    end
  end

  context 'logout' do

    it 'of user1 should be failure because token is invalid' do
      request  = { taskmanager: { auth_token: 'invalid_token' }}
      post '/protected/logout', request.to_json

      response = { logout: { error: '403 Forbidden' }}

      last_response.body.should == response.to_json
    end

    it 'of user1 should be successful' do
      request  = { taskmanager: { auth_token: User.first.token }}
      post '/protected/logout', request.to_json

      response = { logout: { error: 'Success' }}

      last_response.body.should == response.to_json
    end
  end

  context 'delete' do
    it 'of user1 should be successful' do
      request  = { taskmanager: { auth_token: User.first.token }}
      post '/protected/delete_user', request.to_json

      response = { delete_user: { error: 'Success' }}
      last_response.body.should == response.to_json
    end
  end

  context 'restore' do
    it 'of user1 should be successful' do
      request  = { taskmanager: { auth_token: User.first.token }}
      post '/protected/restore_user', request.to_json

      response = { restore_user: { error: 'Success' }}
      last_response.body.should == response.to_json
    end
  end

  context 'find_user(search)' do
    it 'of user2 should be successful' do
      request  = { taskmanager: { auth_token:   User.first.token,
                                  search_value: User.last.login }}
      post '/protected/find_user', request.to_json

      response = { find_user: { error: 'Success',
                                users: [{ login:     User.last.login,
                                          firstname: User.last.firstname,
                                          lastname:  User.last.lastname }]}}
      last_response.body.should == response.to_json
    end

    it 'of user2 should be failure because of empty fields' do
      request  = { taskmanager: { auth_token:   User.first.token,
                                  search_value: '' }}
      post '/protected/find_user', request.to_json

      response = { find_user: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

    it 'of user should be failure because of short search_value' do
      request  = { taskmanager: { auth_token:   User.first.token,
                                  search_value: 'u' }}
      post '/protected/find_user', request.to_json

      response = { find_user: { error: 'Need at least 2 characters' }}
      last_response.body.should == response.to_json
    end

    it 'of user should be failure because such user doesn\'t exist' do
      request  = { taskmanager: { auth_token:   User.first.token,
                                  search_value: 'user' }}
      post '/protected/find_user', request.to_json

      response = { find_user: { error: 'No matching users' }}
      last_response.body.should == response.to_json
    end
  end

  context 'add_friend(invite)' do
    it ' to friends user2 should be failure because of priority' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login,
                                  priority:       3 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'Wrong priority' }}
      last_response.body.should == response.to_json
    end

    it ' to friends user2 should be successful' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login,
                                  priority:       4 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'Success' }}
      last_response.body.should == response.to_json
    end

    it ' to friends user2 should be failure because of invite already exists' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login,
                                  priority:       4 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'Invite exists' }}
      last_response.body.should == response.to_json
    end

    it ' to friends user1 should be failure because of existing invite ' do
      request  = { taskmanager: { auth_token:     User.last.token,
                                  receiver_login: User.first.login,
                                  priority:       4 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'You have invite from this user' }}
      last_response.body.should == response.to_json
    end
  end

  context 'add_friend(response)' do
    it 'on invite from user2 to user1 should be failure because of empty fields' do
      request  = { taskmanager: { auth_token:     User.last.token,
                                  receiver_login: '',
                                  friendship:     'true',
                                  priority:       5 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

    it 'on invite from user2 to user should be failure because user doesn\'t exists' do
      request  = { taskmanager: { auth_token:     User.last.token,
                                  receiver_login: 'nothing',
                                  friendship:     'true',
                                  priority:       5 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'User doesn\'t exist' }}
      last_response.body.should == response.to_json
    end

    it 'on invite from user2 to user2 should be failure' do
      request  = { taskmanager: { auth_token:     User.last.token,
                                  receiver_login: User.last.login,
                                  friendship:     'true',
                                  priority:       5 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'You can\'t add yourself to friends' }}
      last_response.body.should == response.to_json
    end

    it 'on invite from user2 to user1 should be successful(false)' do
      request  = { taskmanager: { auth_token:     User.last.token,
                                  receiver_login: User.first.login,
                                  friendship:     'false',
                                  priority:       5 }}
      post '/protected/add_friend', request.to_json

      response = { add_friend: { error: 'Success' }}
      last_response.body.should == response.to_json
    end

    it 'on invite from user2 to user1 should be successful(true)' do
      request_invite  = { taskmanager: { auth_token:     User.first.token,
                                         receiver_login: User.last.login,
                                         priority:       4 }}
      post '/protected/add_friend', request_invite.to_json

      request_response  = { taskmanager: { auth_token:     User.last.token,
                                           receiver_login: User.first.login,
                                           friendship:     'true',
                                           priority:       5 }}
      post '/protected/add_friend', request_response.to_json

      response = { add_friend: { error:     'Success',
                                 login:     User.first.login,
                                 firstname: User.first.firstname,
                                 lastname:  User.first.lastname }}
      last_response.body.should == response.to_json
    end
  end

  context 'new_task' do
    it ' to user2 should be failure because of empty fields' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login,
                                  content:        '',
                                  priority:       1 }}
      post '/protected/new_task', request.to_json

      response = { new_task: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

    it ' to user should be failure because such user doesn\'t exists' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: 'nothing',
                                  content:        'content',
                                  priority:       1 }}
      post '/protected/new_task', request.to_json

      response = { new_task: { error: 'User doesn\'t exist' }}
      last_response.body.should == response.to_json
    end

    it ' to user1 from user1 should be failure ' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.first.login,
                                  content:        'content',
                                  priority:       1 }}
      post '/protected/new_task', request.to_json

      response = { new_task: { error: 'You can\'t be receiver' }}
      last_response.body.should == response.to_json
    end

    it ' to user3 from user1 should be failure because they aren\'t friends' do
      User.create( login:     'login3',
                   password:  'password3',
                   firstname: 'firstname3',
                   lastname:  'lastname3',
                   token:     'user3token')

      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.first(login: 'login3').login,
                                  content:        'content',
                                  priority:       1 }}
      post '/protected/new_task', request.to_json

      response = { new_task: { error: 'This is not your friend' }}
      last_response.body.should == response.to_json
    end

    it ' to user1 from user2 should be successful ' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.first(login: 'login2').login,
                                  content:        'content',
                                  priority:       1 }}
      post '/protected/new_task', request.to_json

      response = { new_task: { error: 'Success' }}
      last_response.body.should == response.to_json
    end

    after(:all) do
      User.first(login: 'login3').destroy!
    end
  end

  context 'get_task' do
    it ' user2 should be successful' do
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

    it ' user2 should be successful(empty)' do
      request  = { taskmanager: { auth_token: User.last.token }}
      response = { get_task: { error:    'Success',
                               quantity: Task.all(receiver_login: User.last.login, read: false).size }}

      post '/protected/get_task', request.to_json
      last_response.body.should == response.to_json
    end
  end

  context 'delete_task' do
    it ' should be failure because of empty fields' do
      request  = { taskmanager: { auth_token: User.last.token,
                                  task_id:    nil }}
      post '/protected/delete_task', request.to_json

      response = { delete_task: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

     it ' should be failure because task doesn\'t exists' do
      request  = { taskmanager: { auth_token: User.last.token,
                                  task_id:    0 }}
      post '/protected/delete_task', request.to_json

      response = { delete_task: { error: 'Task doesn\'t exist' }}
      last_response.body.should == response.to_json
    end

    it ' should be successful' do
      task_id  = Task.all(receiver_login: User.last.login).last(read: true).id
      request  = { taskmanager: { auth_token: User.last.token,
                                  task_id:    task_id }}
      post '/protected/delete_task', request.to_json

      response = { delete_task: { error: 'Success' }}
      last_response.body.should == response.to_json
    end
  end

  context 'delete_friend' do
    it ' should be failure because of empty fields' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: '' }}
      post '/protected/delete_friend', request.to_json

      response = { delete_friend: { error: 'Empty fields' }}
      last_response.body.should == response.to_json
    end

     it ' should be failure because user doesn\'t exists' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: 'nothing' }}
      post '/protected/delete_friend', request.to_json

      response = { delete_friend: { error: 'User doesn\'t exist' }}
      last_response.body.should == response.to_json
    end

    it ' should be successful' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login }}
      post '/protected/delete_friend', request.to_json

      response = { delete_friend: { error: 'Success' }}
      last_response.body.should == response.to_json
    end

    it ' should be failure because users aren\'t friends' do
      request  = { taskmanager: { auth_token:     User.first.token,
                                  receiver_login: User.last.login }}
      post '/protected/delete_friend', request.to_json

      response = { delete_friend: { error: 'This is not your friend' }}
      last_response.body.should == response.to_json
    end
  end
end
