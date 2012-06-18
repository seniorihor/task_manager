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
  property :login,      String, required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String, required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String, required: true, length: 2..20
  property :lastname,   String, required: true, length: 2..20
  property :created_at, DateTime

  has n,   :tasks
end

class Task
  include DataMapper::Resource

  property   :id,           Serial
  property   :content,      Text, required: true
  property   :priority,     Enum[1, 2, 3]
  property   :created_at,   DateTime
  property   :user_id,      Integer
  property   :receiver_id,  Integer

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
use Rack::Session::Pool, expire_after: 2592000

# Filters
before do
  content_type :json
end

before '/protected/*' do
  hash  = to_hash(request.body.read)
  @auth = session.has_value?(hash["taskmanager"]["auth_token"]) ? true : false
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
      session[user] = auth_token
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

    user = session.key(auth_token)
    return {newtask: {error: "Empty fields"}}.to_json if content.empty? || priority.nil?

    task             = Task.new
    task.content     = content
    task.priority    = priority
    task.user_id     = user.id
    task.receiver_id = User.first(login: receiver_login).id

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
    add_new_user( hash["taskmanager"]["login"],
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
    hash = to_hash(request.body.read)
    add_new_task( hash["taskmanager"]["content"],
                  hash["taskmanager"]["priority"],
                  hash["taskmanager"]["receiver_login"],
                  hash["taskmanager"]["auth_token"])
  else
    {session: {error: "403 Forbidden"}.to_json
  end
end

post '/protected/logout' do
  if @auth
    hash = to_hash(request.body.read)
    user = session.key(hash["taskmanager"]["auth_token"])
    session[user].clear
    {logout: {error: "Success"}}.to_json
  else
    {session: {error: "403 Forbidden"}.to_json
  end
end
