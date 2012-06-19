# -*- coding: utf-8 -*-

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
  property :created_at, DateTime

  # юзер є власником безлічі тасків
  has n, :authorships
  has n, :tasks, :through => :authorships

  # юзер є власником безлічі френдів
  has n, :userfriends
  has n, :friends, :through => :userfriends
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

  # таск має одного юзера
  has n, :authorships
  has 1, :owner, :model => 'User', :through => :authorships, :via => :user
end

class Friend
  include DataMapper::Resource

  property :id,         Serial
  property :login,      String,  required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String,  required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String,  required: true, length: 2..20
  property :lastname,   String,  required: true, length: 2..20
  property :created_at, DateTime

  # френд має одного юзера
  has n, :userfriends
  has 1, :owner, :model => 'User', :through => :userfriends, :via => :user
end

class Authorship
  include DataMapper::Resource

  belongs_to :user, :key => true
  belongs_to :task, :key => true
end

class Userfriend
  include DataMapper::Resource

  belongs_to :user,   :key => true
  belongs_to :friend, :key => true
end

DataMapper.finalize
DataMapper.auto_upgrade!
