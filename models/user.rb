class User
  include DataMapper::Resource

  property :id,         Serial
  property :login,      String,   required: true, length: 2..20, format: /[a-zA-Z]/, unique: true
  property :password,   String,   required: true, length: 6..20, format: /[a-zA-Z]/
  property :firstname,  String,   required: true, length: 2..20
  property :lastname,   String,   required: true, length: 2..20
  property :token,      String,   length:   10
  property :created_at, DateTime
  property :deleted,    Boolean,  required: true, default: false

  has n,   :friendships, child_key: [:source_id]
  has n,   :friends,     self,      through: :friendships, via: :target
  has n,   :tasks
end
