# -*- coding: utf-8 -*-

require 'sinatra'
require 'bundler/setup'
require 'sinatra/reloader'
require 'dm-core'
require 'dm-sqlite-adapter'
require 'dm-validations'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-types'
require 'dm-serializer/to_json'
require 'json'

set :environment, ENV['RACK_ENV'] || :development
                                     #:test

# Configuration connection to database
configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/development.db")
  DataMapper::Logger.new($stdout, :debug)
end

configure :test do
  DataMapper.setup(:default, 'sqlite::memory:')
end

DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)


# Model
class User
  include DataMapper::Resource

  property :id,         Serial
  property :login,      String,  required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String,  required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String,  required: true, length: 2..20
  property :lastname,   String,  required: true, length: 2..20
  property :token,      String,  length:   10
  property :created_at, DateTime
  property :deleted,    Boolean, required: true, default: false

  has n,   :friendships, child_key: [:source_id]
  has n,   :friends,     self,      through: :friendships, via: :target
  has n,   :tasks
end

class Task
  include DataMapper::Resource

  property :id,             Serial
  property :content,        Text,    required: true
  property :priority,       Enum[1, 2, 3, # task priority
                                 4,       # invite friend
                                 5,       # add friend
                                 6]       # delete friend
  property :created_at,     DateTime
  property :receiver_login, String,  required: true, length:  2..20, format: /[a-zA-Z]/
  property :read,           Boolean, required: true, default: false

  belongs_to :user
end

class Friendship
  include DataMapper::Resource

  belongs_to :source, 'User', key: true
  belongs_to :target, 'User', key: true
end

DataMapper.finalize
DataMapper.auto_upgrade!


# Filters
before do
  content_type :json
end

before '/protected/*' do
  json_data = request.body.read

  if json_data.empty?
    @auth = false
  else
    @protected_hash = to_hash(json_data)
    user = User.first(token: @protected_hash['taskmanager']['auth_token'])

    if user.nil?
      @auth = false
    elsif user.deleted
      @auth         = false
      @restore_auth = true
    else
      @auth = true
    end
  end
end


# Helpers
helpers do

  def new_token
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map { |r| r.to_a }.flatten
    Array.new(10).map { chars[rand(chars.size)] }.join
  end

  def to_hash(json_data)
    JSON.parse(json_data)
  end

  def login_exists?(login)
    User.first(login: login).nil? ? false : true
  end

  def login(login, password)
    user = User.first(login: login)

    return {login: {error: 'Invalid login or password'}}.to_json if user.nil?

    if password == user.password
      user.token = new_token
      user.save
      friends = Array.new(user.friends)
      friends.map! { |friend| {login: friend.login}}
      {login: {error: 'Success', auth_token: user.token, friends: friends}}.to_json
    else
      {login: {error: 'Invalid login or password'}}.to_json
    end
  end

  def logout(auth_token)
    user       = User.first(token: auth_token)
    user.token = nil
    user.save
    {logout: {error: 'Success'}}.to_json
  end

  def add_new_user(login, password, firstname, lastname)
    return {register: {error: 'Empty fields'}}.to_json if login.empty?     ||
                                                          password.empty?  ||
                                                          firstname.empty? ||
                                                          lastname.empty?

    user           = User.new
    user.login     = login
    user.password  = password
    user.firstname = firstname
    user.lastname  = lastname

    if user.save
      {register: {error: 'Success'}}.to_json
    else
      error = user.errors.each { |error| error }
      {register: error}.to_json
    end
  end

  def delete_user(auth_token)
    user = User.first(token: auth_token)
    user.deleted = true

    if user.save
      {delete_user: {error:    'Success',
                     deleting: true}}.to_json
    else
      {delete_user: {error:    'Success',
                     deleting: false}}.to_json
    end
  end

  def restore_user(auth_token)
    user = User.first(token: auth_token)
    user.deleted = false

    if user.save
      {restore_user: {error:     'Success',
                      restoring: true}}.to_json
    else
      {restore_user: {error: 'Success',
                      restoring: false}}.to_json
    end
  end

  def find_user(auth_token, search_value)
    return {find_user: {error: 'Empty fields'}}.to_json if search_value.empty?

    users              = Array.new
    users_by_login     = Array.new(User.all(login:     search_value))
    users_by_firstname = Array.new(User.all(firstname: search_value))
    users_by_lastname  = Array.new(User.all(lastname:  search_value))


    users_by_login.each     { |user| users << user } unless users_by_login.empty?
    users_by_firstname.each { |user| users << user } unless users_by_firstname.empty?
    users_by_lastname.each  { |user| users << user } unless users_by_lastname.empty?

    users.map! { |user| {login:     user.login,
                         firstname: user.firstname,
                         lastname:  user.lastname}}
    {find_user: {error: 'Success',
                 users: users}}.to_json
  end

  def add_friend(auth_token, receiver_login, content)
    return {add_friend: {error: 'Empty fields'}}.to_json if content.empty? ||
                                                            receiver_login.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return {add_friend: {error: "User doesn't exist"}}.to_json                if receiver.nil?
    return {add_friend: {error: "You can't add yourself to friends"}}.to_json if sender == receiver
    return {add_friend: {error: 'User is deleted'}}.to_json                   if receiver.deleted

    invite_task = receiver.tasks.all(receiver_login: sender.login).last(priority: 4)

    return {add_friend: {error: "Invite doesn't exist"}}.to_json if invite_task.nil?

    if content == 'true'
      sender.friends   << receiver
      receiver.friends << sender

      if sender.friends.save && receiver.friends.save
        add_new_task(sender.token, receiver.login, 'true', 5)
        invite_task.destroy!
        {add_friend: {error:      'Success',
                      friendship: true}}.to_json
      else
        add_new_task(sender.token, receiver.login, 'false', 5)
        invite_task.destroy!
        {add_friend: {error:      'Success',
                      friendship: false}}.to_json
      end

    else
      add_new_task(sender.token, receiver.login, 'false', 5)
      invite_task.destroy!
      {add_friend: {error:      'Success',
                    friendship: false}}.to_json
    end
  end

  def delete_friend(auth_token, receiver_login)
    return {delete_friend: {error: 'Empty fields'}}.to_json if receiver_login.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return {delete_friend: {error: "User doesn't exist"}}.to_json      if receiver.nil?
    return {delete_friend: {error: 'This is not your friend'}}.to_json unless sender.friends.include?(receiver)

    sender.friends.delete(receiver)
    receiver.friends.delete(sender)

    if sender.friends.save && receiver.friends.save
      add_new_task(sender.token, receiver.login, 'true', 6)
      {delete_friend: {error:    'Success',
                       deleting: true}}.to_json
    else
      {delete_friend: {error:    'Success',
                       deleting: false}}.to_json
    end
  end

  def add_new_task(auth_token, receiver_login, content, priority)
    return {new_task: {error: 'Empty fields'}}.to_json if content.empty? ||
                                                          priority.nil?  ||
                                                          receiver_login.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return {new_task: {error: "User doesn't exist"}}.to_json    if receiver.nil?
    return {new_task: {error: "You can't be receiver"}}.to_json if sender == receiver
    return {new_task: {error: 'User is deleted'}}.to_json       if receiver.deleted

    case priority
    when 1..3
      return {new_task: {error: 'This is not your friend'}}.to_json unless sender.friends.include?(receiver)
    end

    return {add_friend: {error: 'Already friend'}}.to_json if sender.friends.include?(receiver) &&
                                                              priority == 4

    invite_task = sender.tasks.all(receiver_login: receiver.login).last(priority: 4)

    return {new_task: {error: 'Invite exists'}}.to_json if invite_task

    task                = Task.new
    task.content        = content
    task.priority       = priority
    task.user_id        = sender.id
    task.receiver_login = User.first(login: receiver_login).login

    if task.save && priority == 4
      {add_friend: {error: 'Success'}}.to_json
    elsif task.save
      {new_task: {error: 'Success'}}.to_json
    else
      error = task.errors.each { |error| error }
      {new_task: {error: error}}.to_json
    end
  end

  def delete_task(auth_token, task_id)
    return {delete_task: {error: 'Empty fields'}}.to_json if task_id.nil?

    user = User.first(token: auth_token)
    task = Task.all(receiver_login: user.login).get(task_id)

    return {delete_task: {error: "Task doesn't exist"}}.to_json if task.nil?

    if task.destroy!
      {delete_task: {error:    'Success',
                     deleting: true}}.to_json
    else
      {delete_task: {error:    'Success',
                     deleting: false}}.to_json
    end
  end

  def get_task(auth_token)
    user       = User.first(token: auth_token)
    collection = Task.all(read: false, receiver_login: user.login)

    return {get_task: {error: 'No messages'}}.to_json if collection.empty?

    tasks    = Array.new(collection)
    quantity = tasks.size

    tasks.each do |task|
         task.read = true
         task.save
    end

    tasks.map! { |task| {content:    task.content,
                      	 priority:   task.priority,
                      	 user_login: User.get(task.user_id).login,
                      	 created_at: task.created_at}}

    # Delete all temporary tasks
    add_friend_tasks    = Array.new(Task.all(receiver_login: user.login, read: true, priority: 5))
    delete_friend_tasks = Array.new(Task.all(receiver_login: user.login, read: true, priority: 6))
    add_friend_tasks.each    { |task| task.destroy! } unless add_friend_tasks.empty?
    delete_friend_tasks.each { |task| task.destroy! } unless delete_friend_tasks.empty?

    {get_task: {error:    'Success',
                quantity: quantity,
                tasks:    tasks}}.to_json
  end
end


# Login user
post '/login' do
  @hash = to_hash(request.body.read)

  login(@hash['taskmanager']['login'],
        @hash['taskmanager']['password'])
end

# Logout user
post '/protected/logout' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  logout(@protected_hash['taskmanager']['auth_token'])
end

# Register user
post '/register' do
  @hash = to_hash(request.body.read)

  if login_exists?(@hash['taskmanager']['login'])
    {register: {error: 'Login exists'}}.to_json
  else
    add_new_user(@hash['taskmanager']['login'],
                 @hash['taskmanager']['password'],
                 @hash['taskmanager']['firstname'],
                 @hash['taskmanager']['lastname'])
  end
end

# Delete user
post '/protected/delete_user' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  delete_user(@protected_hash['taskmanager']['auth_token'])
end

# Restore user
post '/protected/restore_user' do
  return {session: {error: '403 Forbidden'}}.to_json unless @restore_auth

  restore_user(@protected_hash['taskmanager']['auth_token'])
end

# Find user
post '/protected/find_user' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  find_user(@protected_hash['taskmanager']['auth_token'],
            @protected_hash['taskmanager']['search_value'])
end

# Add friend
post '/protected/add_friend' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  case @protected_hash['taskmanager']['priority']
  when 4
    add_new_task(@protected_hash['taskmanager']['auth_token'],
                 @protected_hash['taskmanager']['receiver_login'],
                 @protected_hash['taskmanager']['content'],
                 @protected_hash['taskmanager']['priority'])
  when 5
    add_friend(@protected_hash['taskmanager']['auth_token'],
               @protected_hash['taskmanager']['receiver_login'],
               @protected_hash['taskmanager']['content'])
  else
    {add_friend: {error: 'Wrong priority'}}.to_json
  end
end

# Delete friend
post '/protected/delete_friend' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  delete_friend(@protected_hash['taskmanager']['auth_token'],
                @protected_hash['taskmanager']['receiver_login'])
end

# Create new task
post '/protected/new_task' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  add_new_task(@protected_hash['taskmanager']['auth_token'],
               @protected_hash['taskmanager']['receiver_login'],
               @protected_hash['taskmanager']['content'],
               @protected_hash['taskmanager']['priority'])
end

# Delete task
post '/protected/delete_task' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  delete_task(@protected_hash['taskmanager']['auth_token'],
              @protected_hash['taskmanager']['task_id'])
end

# List all tasks
post '/protected/get_task' do
  return {session: {error: '403 Forbidden'}}.to_json unless @auth

  get_task(@protected_hash['taskmanager']['auth_token'])
end
