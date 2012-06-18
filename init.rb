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
  property :login,      String, required: true, length: 2..20, format: /[a-zA-Z]/, unique: true,
                    messages: { presence: 1,    length: 2,     format: 3,          is_unique: 4}
  property :password,   String, required: true, length: 6..20, format: /[a-zA-Z]/,
                    messages: { presence: 1,    length: 2,     format: 3}
  property :firstname,  String, required: true, length: 2..20,
                    messages: { presence: 1,    length: 2}
  property :lastname,   String, required: true, length: 2..20,
                    messages: { presence: 1,    length: 2}
  property :created_at, DateTime

  has n,   :tasks
end


class Task
  include DataMapper::Resource

  property   :id,           Serial
  property   :content,      Text, required: true,
                      messages: { presence: 1,    length: 2 }
  property   :priority,     Enum[1, 2, 3],
                      messages: { check_enum: 5 } # fix it
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

before '/protected/*/?' do
  hash  = to_hash(params[:data])
  @auth = User.first(token: hash["token"]).nil? ? false : true
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
    false if user.nil?
    if password == user.password
      token = Token.generate
      user.token = token
      session[user] = token
      user.save
      {login: true, token: token}
    else
      {login: false}
    end
  end

  def add_new_user(login, password, firstname, lastname)

    return {registration: false} if login.empty? || password.empty? || firstname.empty? || lastname.empty?

    @user           = User.new
    @user.login     = login
    @user.password  = password
    @user.firstname = firstname
    @user.lastname  = lastname
    if @user.save
      {registration: true}
    else
      error = @user.errors.each { |error| error }
      {registration: error}
    end
  end

  def add_new_task(content, priority, receiver_id, token)

    return {newtask: false} if content.empty? || priority.nil?

    task             = Task.new
    task.content     = content
    task.priority    = priority
    task.user_id     = @user.id
    task.receiver_id = User.first(id: receiver_id).id

    if task.save
      {newtask: true}
    else
      error = task.errors.each { |error| error }
      {newtask: error}
    end
  end
end


# Routes
post '/registration/?' do
  hash = to_hash(params[:data])
  if login_exists?(hash["login"])
    {registration: 'false'}
  else
    add_new_user(hash["login"], hash["password"], hash["firstname"], hash["lastname"])
  end
end

post '/login' do
  p hash = to_hash(request.body.read)
  #login(hash["login"], hash["password"])
  if hash['taskmanager']['login'] == 'qwerty' && hash['taskmanager']['password'] == '123'
    {"error":"Success"}
  else
    {"error":"Some Error"}
  end
end

post '/protected/newtask/?' do
  if @auth
    hash = to_hash(params[:data])
    add_new_task(hash["content"], hash["priority"], hash["receiver_id"], hash["token"])
  else
    {auth: false}
  end
end

get '/protected/logout/?' do
  if @auth
    hash = to_hash(params[:data])
    user = User.first(token: hash["token"])
    session[user].clear
    {logout: true}
  else
    {auth: false}
  end
end
