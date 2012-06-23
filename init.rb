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

# A Sqlite3 connection to a persistent database
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.sqlite3")
DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)

class User
  include DataMapper::Resource

  property :id,         Serial
  property :login,      String,  required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String,  required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String,  required: true, length: 2..20
  property :lastname,   String,  required: true, length: 2..20
  property :token,      String,  length: 10
  property :created_at, DateTime

  has n,   :friendships,   child_key: [:source_id]
  has n,   :friends, self, through:   :friendships, via: :target
  has n,   :tasks
end

class Task
  include DataMapper::Resource

  property :id,             Serial
  property :content,        Text,         required: true
  property :priority,       Enum[1, 2, 3]
  property :created_at,     DateTime
  property :receiver_login, String,       required: true, length: 2..20, format: /[a-zA-Z]/
  property :read,           Boolean,      default:  false

  belongs_to :user
end

class Friendship
  include DataMapper::Resource

  belongs_to :source, 'User', key: true
  belongs_to :target, 'User', key: true
end

class Token

  def self.generate
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map{|r|r.to_a}.flatten
    Array.new(10).map{chars[rand(chars.size)]}.join
  end
end

# Filter

before do
  content_type :json
end

before '/protected/*'  do
  @protected_hash = to_hash(request.body.read)
  @auth = User.first(token: @protected_hash["taskmanager"]["auth_token"]).nil? ? false : true
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
      {login: {error: "Success", auth_token: user.token}}.to_json
    else
      {login: {error: "Invalid login or password"}}.to_json
    end
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

  def add_new_task(content, priority, receiver_login, auth_token)

    user = User.first(token: auth_token)
    return {newtask: {error: "Empty fields"}}.to_json if content.empty? || priority.nil?

    task                = Task.new
    task.content        = content
    task.priority       = priority
    task.user_id        = user.id
    task.receiver_login = User.first(login: receiver_login).login

    if task.save
      {newtask: {error: "Success"}}.to_json
    else
      #error = task.errors.each { |error| error }
      {newtask: "bad"}.to_json
    end
  end
end

# Register

post '/register' do
  @hash = to_hash(request.body.read)
  unless @auth
    if login_exists?(@hash["taskmanager"]["login"])
      {register: {error: "Login exists"}}.to_json
    else
      add_new_user(@hash["taskmanager"]["login"],
                   @hash["taskmanager"]["password"],
                   @hash["taskmanager"]["firstname"],
                   @hash["taskmanager"]["lastname"])
    end
  else
    {register: {error: "Already in session"}}.to_json
  end
end

# Login
post '/login' do
  @hash = to_hash(request.body.read)
  unless @auth
    login(@hash["taskmanager"]["login"],
          @hash["taskmanager"]["password"])
  else
    {login: {error: "Already in session"}}.to_json
  end
end

# Create new task
post '/protected/new_task' do
  if @auth
    add_new_task(@protected_hash["taskmanager"]["content"],
                 @protected_hash["taskmanager"]["priority"],
                 @protected_hash["taskmanager"]["receiver_login"],
                 @protected_hash["taskmanager"]["auth_token"])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Logout
post '/protected/logout' do
  if @auth
    user       = User.first(token: @protected_hash["taskmanager"]["auth_token"])
    user.token = nil
    user.save
    {logout: {error: "Success"}}.to_json
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# List all tasks
post '/protected/get_task' do
  if @auth
    user = User.first(token: @protected_hash["taskmanager"]["auth_token"])
    collection = Task.all(read: false, receiver_login: user.login)
    return {get_task: {error: "No messages"}}.to_json if collection.empty?
    
    tasks = Array.new(collection)
    quantity = tasks.size

    tasks.each do |task|
         task.read = true
         task.save
    end
    tasks.map! {|task|     {:content =>        task.content,
                            :priority =>       task.priority,
                            :receiver_login => task.receiver_login,
                            :created_at =>     task.created_at}}

    {get_task: {error: "Success", quantity: quantity, tasks: tasks}}.to_json
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

# Find user
post '/protected/find_user' do
  if @auth
    find_user = User.first(login: @protected_hash["taskmanager"]["login"])
    {find_user: {error:       "Success",
                 firstname:   find_user.firstname,
                 lastname:    find_user.lastname,
                 login:       find_user.login}}.to_json
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

DataMapper.auto_upgrade!
