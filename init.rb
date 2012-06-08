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
  property :username,   String, required: true, length: 2..20, unique: true
  property :password,   String, required: true, length: 6..20
  property :first_name, String, required: true, length: 2..20
  property :last_name,  String, required: true, length: 2..20
  property :created_at, DateTime

  has n,   :tasks

  def initialize(username, password, first_name = nil, last_name = nil)
    @username   = username
    @password   = password
    @first_name = first_name
    @last_name  = last_name
  end

  def register
    self.username   = @username
    self.password   = @password
    self.first_name = @first_name
    self.last_name  = @last_name
    self.save
  end

  def login
    user = User.first(username: @username)
    user.nil? ? false : password == user.password
  end
end


class Task
  include DataMapper::Resource

  property   :id,           Serial
  property   :content,      String,    required: true
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
    self.save
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!

#валідація на всі поля (кирилиця...)
#повертати помилку, яка виникає при реєстрації (обробка помилок)
#валідація на content до 140 символів
#обробка помилок і повернення значення
