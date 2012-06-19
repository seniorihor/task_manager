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

# Database
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.sqlite3")
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
  property :created_at, DateTime
  
  has n,   :tasks
end

class Task
  include DataMapper::Resource

  property :id,             Serial
  property :content,        Text,         required: true
  property :priority,       Enum[1, 2, 3]
  property :created_at,     DateTime
  property :user_id,        Integer
  property :receiver_login, String,       required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :read,           Boolean,      default: false

  belongs_to :user
end

DataMapper.finalize
DataMapper.auto_upgrade!

class Token

  def self.generate
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map{|r|r.to_a}.flatten
    Array.new(10).map{chars[rand(chars.size)]}.join
  end
end

# Controller

# Filters
before do
  content_type :json
end

before '/protected/*' do
  @hash  = to_hash(request.body.read)
  @auth = User.first(token: hash["taskmanager"]["auth_token"]).nil? ? false : true
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
      auth_token = Token.generate
      user.token = auth_token
      user.save
      {login: {error: "Success",auth_token: auth_token}}.to_json
    else
      {login: {error: "Invalid login or password"}}.to_json
    end
  end

  def add_new_user(login, password, firstname, lastname)

    return {registration: {error: "Empty fields"}}.to_json if login.empty? || password.empty? || firstname.empty? || lastname.empty?
    user           = User.new
    user.login     = login
    user.password  = password
    user.firstname = firstname
    user.lastname  = lastname
    if user.save
      {registration: {error: "Success"}}.to_json
    else
      error = user.errors.each { |error| error }
      {registration: error}.to_json
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
      error = task.errors.each { |error| error }
      {newtask: error}.to_json
    end
  end
end

# Routes
post '/registration' do
  hash = to_hash(request.body.read)
  if login_exists?(hash["taskmanager"]["login"])
    {registration: {error: "Login exists"}}.to_json
  else
    add_new_user(hash["taskmanager"]["login"],
                 hash["taskmanager"]["password"],
                 hash["taskmanager"]["firstname"],
                 hash["taskmanager"]["lastname"])
  end
end

post '/login' do
  hash = to_hash(request.body.read)
  login(hash["taskmanager"]["login"],
        hash["taskmanager"]["password"])
end

post '/protected/newtask' do
  if @auth
    add_new_task(@hash["taskmanager"]["content"],
                 @hash["taskmanager"]["priority"],
                 @hash["taskmanager"]["receiver_login"],
                 @hash["taskmanager"]["auth_token"])
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

post '/protected/logout' do
  if @auth
    user = User.first(token: @hash["taskmanager"]["auth_token"])
    user.token = nil
    user.save
    {logout: {error: "Success"}}.to_json
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

post '/protected/get_task' do
  if @auth
    user = User.first(token: @hash["taskmanager"]["auth_token"])
    tasks = Task.all(read: false, receiver_login: user.login)
    if tasks.nil?
      {get_task: {error: "No messages"}}.to_json
    else
      quantity = tasks.size
      tasks.each do |task|
          task.read = true
          task.save
      end
      tasks.map! do |task| {get_task: {error:          "Success",
                                       quantity:       quantity,
                                       content:        task.content,
                                       priority:       task.priority,
                                       receiver_login: task.receiver_login,
                                       time:           task.created_at}}
      end
      tasks.to_json
    end
  else
    {session: {error: "403 Forbidden"}}.to_json
  end
end

post '/protected/find_user' do
  if @auth
    find_user = User.first(login: @hash["taskmanager"]["login"])
    {find_user: {error:       "Success", 
                 firstname:   find_user.firstname, 
                 lastname:    find_user.lastname, 
                 login:       find_user.login}}
  else
    {session: {error: "403 Forbidden"}}.to_json
  end  
end  