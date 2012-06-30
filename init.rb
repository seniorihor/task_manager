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

set :environment, ENV['RACK_ENV'] || :development # or :test

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
  property :priority,       Enum[0, 10, 1, 2, 3] # 0 - invite; 10 - response; 1-3 - priority
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


class Token

  def self.generate
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map{|r|r.to_a}.flatten
    Array.new(10).map{chars[rand(chars.size)]}.join
  end
end


# Filters
before do
  content_type :json
end

before '/protected/*'  do
  @protected_hash = to_hash(request.body.read)
  @auth = User.first(token: @protected_hash['taskmanager']['auth_token']).nil? ? false : true
end


# Helpers
helpers do

  def to_hash(json_data)
    return JSON.parse(json_data)
  end

  def login_exists?(login)
    User.first(login: login).nil? ? false : true
  end

  def login(login, password)
    user = User.first(login: login)
    return {login: {error: "Invalid login or password"}}.to_json if user.nil?
    if password == user.password
      user.token = Token.generate
      user.save
      friends = Array.new(user.friends)
      friends.map! { |friend| {login: friend.login}}
      {login: {error: "Success", auth_token: user.token, friends: friends}}.to_json
    else
      {login: {error: "Invalid login or password"}}.to_json
    end
  end

  def logout(auth_token)

    user       = User.first(token: auth_token)
    user.token = nil
    user.save
    {logout: {error: "Success"}}.to_json
  end

  def add_new_user(login, password, firstname, lastname)

    return {register: {error: "Empty fields"}}.to_json if login.empty? || password.empty? || firstname.empty? || lastname.empty?
    user           = User.new
    user.login     = login
    user.password  = password
    user.firstname = firstname
    user.lastname  = lastname

    if user.save
      {register: {error: "Success"}}.to_json
    else
      error = user.errors.each { |error| error }
      {register: error}.to_json
    end
  end

  def delete_user(auth_token)

    user = User.first(token: auth_token)
    user.deleted = true
    if user.save
      {delete_user: {error: "Success"}}.to_json
    else
      error = user.errors.each { |error| error }
      {delete_user: error}.to_json
    end
  end

  def restore_user(auth_token)

    user = User.first(token: auth_token)
    user.deleted = false
    if user.save
      {restore_user: {error: "Success"}}.to_json
    else
      error = user.errors.each { |error| error }
      {restore_user: error}.to_json
    end
  end

  def find_user(auth_token, search_value)

    users = User.all(:login.like => search_value) | User.all(:firstname.like => search_value) | User.all(:lastname.like => search_value)
    return {find_user: {error: "User doesn't exist"}}.to_json if users.empty?
    users.map! { |user|  {login:     user.login,
                          firstname: user.firstname,
                          lastname:  user.lastname}}
    {find_user: {error:     "Success",
                 users:     users}}.to_json
  end

  def add_friend(auth_token, receiver_login, invite)

    user   = User.first(token: auth_token)
    friend = User.first(login: receiver_login)

    return {add_friend: {error: "User doesn't exist"}}.to_json if friend.nil?
    if invite
      user.friends   << friend
      friend.friends << user
      user.friends.save
      friend.friends.save
      add_new_task('true', 10, friend.login, user.token)
      task = User.first(token: auth_token).last(priority: 0)
      task.priority = 10
      task.save
      {add_friend: {error:      "Success",
                    friendship: true}}.to_json
    else
      add_new_task('false', 10, friend.login, user.token)
      {add_friend: {error:      "Success",
                    friendship: false}}.to_json
    end
  end

  def delete_friend(auth_token, receiver_login)

    user   = User.first(token: auth_token)
    friend = User.first(login: receiver_login)

    return {delete_friend: {error: "User doesn't exist"}}.to_json if friend.nil?
    user.friends.delete(friend)
    friend.friends.delete(user)
    user.friends.save
    friend.friends.save
    {delete_friend: {error: "Success"}}.to_json
  end

  def add_new_task(content, priority, receiver_login, auth_token)

    user = User.first(token: auth_token)
    return {new_task: {error: "Empty fields"}}.to_json if content.empty? || priority.nil?

    task                = Task.new
    task.content        = content
    task.priority       = priority
    task.user_id        = user.id
    task.receiver_login = User.first(login: receiver_login).login

    if task.save
      {new_task: {error: "Success"}}.to_json
    else
      error = task.errors.each { |error| error }
      {new_task: {error: error}}.to_json
    end
  end

  def delete_task(auth_token, task_id)

    return {delete_task: {error: "Empty fields"}}.to_json if task_id.nil?
    user = User.first(token: auth_token)
    task = Task.all(receiver_login: user.login).get(task_id)
    return {delete_task: {error: "Task doesn't exist"}}.to_json if task.empty?
    if task.destroy!
      {delete_task: {error: "Success"}}.to_json
    else
      {delete_task: {error: "Some error"}}.to_json
    end
  end

  def get_task(auth_token, receiver_login)

    user       = User.first(token: auth_token)
    collection = Task.all(read: false, receiver_login: user.login)

    return {get_task: {error: "No messages"}}.to_json if collection.empty?
    tasks    = Array.new(collection)
    quantity = tasks.size

    tasks.each do |task|
         task.read = true
         task.save
    end
    tasks.map! {|task| {content:    task.content,
                        priority:   task.priority,
                        user_login: User.get(task.user_id).login,
                        created_at: task.created_at}}

    {get_task: {error: "Success",
                quantity: quantity,
                tasks: tasks}}.to_json
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
  if @auth
    logout(@protected_hash['taskmanager']['auth_token'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Register user
post '/register' do
  @hash = to_hash(request.body.read)

  if login_exists?(@hash['taskmanager']['login'])
    {register: {error: "Login exists"}}.to_json
  else
    add_new_user(@hash['taskmanager']['login'],
                 @hash['taskmanager']['password'],
                 @hash['taskmanager']['firstname'],
                 @hash['taskmanager']['lastname'])
  end
end

# Delete user
post '/protected/delete_user' do
  if @auth
    delete_user(@protected_hash['taskmanager']['auth_token'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Restore user
post '/protected/restore_user' do
  if @auth
    restore_user(@protected_hash['taskmanager']['auth_token'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Find user
post '/protected/find_user' do
  if @auth
    find_user(@protected_hash['taskmanager']['auth_token'],
              @protected_hash['taskmanager']['login'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Add friend
post '/protected/add_friend' do
  if @auth
    add_friend(@protected_hash['auth_token'],
               @protected_hash['receiver_login'],
               @protected_hash['invite'])
  else
     {session: {error: "403 Forbidden"}}.to_json
  end
end

# Delete friend
post '/protected/delete_friend' do
  if @auth
    delete_friend(@protected_hash['auth_token'],
                  @protected_hash['receiver_login'])
  else
     {session: {error: "403 Forbidden"}}.to_json
  end
end

# Create new task
post '/protected/new_task' do
  if @auth
    add_new_task(@protected_hash['taskmanager']['content'],
                 @protected_hash['taskmanager']['priority'],
                 @protected_hash['taskmanager']['receiver_login'],
                 @protected_hash['taskmanager']['auth_token'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Delete task
post '/protected/delete_task' do
  if @auth
    delete_task(@protected_hash['taskmanager']['auth_token'],
                @protected_hash['taskmanager']['task_id'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# List all tasks
post '/protected/get_task' do
  if @auth
    get_task(@protected_hash['taskmanager']['auth_token'],
             @protected_hash['taskmanager']['receiver_login'])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end
