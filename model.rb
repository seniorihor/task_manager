# -*- coding: utf-8 -*-

require './controller.rb'
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

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite:///#{Dir.pwd}/index.db")
DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)

class User
  include DataMapper::Resource

  property :id,         Serial
  property :login,      String, required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String, required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String, required: true, length: 2..20
  property :lastname,   String, required: true, length: 2..20
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

  def login
    user = User.first(login: @login)
    user.nil? ? false : password == user.password
  end
end


class Task
  include DataMapper::Resource

  property   :id,           Serial
  property   :content,      Text, required: true
  property   :priority,     Enum[1, 2, 3]
  property   :created_at,   DateTime
  #property   :user_id,      Integer
  property   :recipient_id, Integer

  belongs_to :user

  def initialize(content, priority, user_id, recipient_id)
    @content      = content
    @priority     = priority
    @user_id      = user_id
    @recipient_id = recipient_id
  end

  def create
    self.content      = @content
    self.priority     = @priority
    self.user_id      = @user_id
    self.recipient_id = @recipient_id
    self.save ? true : self.errors.each { |error| error }
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!
