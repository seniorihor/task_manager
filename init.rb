# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/reloader'
require 'bundler/setup'
require 'dm-core'
require 'dm-sqlite-adapter'
require 'dm-validations'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-types'
require 'dm-serializer/to_json'

# Database
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/db.sqlite3")
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

  def initialize(login, password, firstname = nil, lastname = nil)
    @login     = login
    @password  = password
    @firstname = firstname
    @lastname  = lastname
  end

  def register
    self.login     = @login
    self.password  = @password
    self.firstname = @firstname
    self.lastname  = @lastname
    self.save ? true : self.errors.each { |error| error }
  end

  def authentication?
    user = User.first(login: @login)
    user.nil? ? false : password == user.password
  end
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

  def initialize(content, priority, user_id, receiver_id)
    @content     = content
    @priority    = priority
    @user_id     = user_id
    @receiver_id = receiver_id
  end

  def create
    self.content     = @content
    self.priority    = @priority
    self.user_id     = @user_id
    self.receiver_id = @receiver_id
    self.save ? true : self.errors.each { |error| error }
  end
end

#DataMapper.finalize
DataMapper.auto_upgrade!

# Controller
use Rack::Session::Pool, expire_after: 2592000

# Filters
before do
  content_type :json
end

before '/protected/*' do
  @auth = session[:current_user].nil? ? false : true
end

# Helpers
helpers do

  def login_exists?(login)
    User.first(login: login).nil? ? {login_exists: false} : {login_exists: true}
  end

  def login(login, password)
    user = User.new(login, password)
    if user.authentication?
      user = User.first(login: login)
      session[:current_user] = user
      {login: true}
    else
      {login: false}
    end
  end

	def add_new_user(login, password, firstname, lastname)

		user = User.new(login, password, firstname, lastname)
		if login.empty? || password.empty? || firstname.empty? || lastname.empty?
			{registration: false}
		elsif user.register
			{registration: true}
		else
			{registration: user.register}
		end
	end

  def add_new_task(content, priority, user_id)
    user_id     = User.first(login: user_id)
    receiver_id = session[:current_user]
    if content.empty? || priority.empty?
      {newtask: false}
    else
      task = Task.new(content, priority, user_id, receiver_id)
      task.create
      {newtask: true}
    end
  end
end


# Routes

post '/registration' do
	if login_exists?(params[:login])
		{registration: 'false'}
	else
		add_new_user(params[:login], params[:password],	params[:firstname],	params[:lastname])
	end
end

get '/login' do
  login(params[:login], params[:password])
end

post '/protected/newtask' do
	if @auth
    add_new_task(params[:content], params[:priority], params[:user_id])
  else
    {auth: false}
  end
end

get '/protected/logout' do
  if @auth
    session.clear
    {logout: true}
  else
    {auth: false}
  end
end
