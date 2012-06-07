# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/reloader'
require 'bundler/setup'
require 'json'
require 'dm-core'
require 'dm-sqlite-adapter'
require 'dm-validations'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-types'
require 'dm-serializer/to_json'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite:///#{Dir.pwd}/index.db")

class User
  include DataMapper::Resource

  property :id,         Serial
  property :username,   String, required: true, unique: true, length: 2..20
  property :email,      String, required: true, unique: true, format: :email_address
  property :password,   String, required: true, length: 6..20
  property :created_at, DateTime

  has n,   :tasks

  def initialize(username, email = nil, password)
    @username = username
    @email    = email
    @password = password
  end

  def register
    self.username = @username
    self.password = @password
    self.email    = @email
    self.save
  end

  def login
    user = User.first(username: username)
    return false if user.nil?
    password == user.password
  end
end


class Task
  include DataMapper::Resource

  property   :id,           Serial
  property   :title,        String,  required: true
  property   :body,         Text,    required: true
  property   :priority,     Enum[1, 2, 3, 4, 5]
  property   :created_at,   DateTime
  #property   :user_id,      Integer
  property   :recipient_id, Integer
  property   :read,         Boolean, default: false

  belongs_to :user

  def initialize(title, body, priority, user_id, recipient_id)
    @title        = title
    @body         = body
    @priority     = priority
    @user_id      = user_id
    @recipient_id = recipient_id
  end

  def create
    self.title        = @title
    self.body         = @body
    self.priority     = @priority
    self.user_id      = @user_id
    self.recipient_id = @recipient_id
    self.save
  end

  def mark_as_read
    self.read = true
    self.save
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!
