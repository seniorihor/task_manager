class Task
  include DataMapper::Resource

  property :id,             Serial
  property :content,        Text,         required: true
  property :priority,       Enum[1, 2, 3, # task priority
                                 4,       # invite friend
                                 5,       # add friend
                                 6]       # delete friend
  property :created_at,     DateTime
  property :receiver_login, String,       required: true, length:  2..20, format: /[a-zA-Z]/
  property :read,           Boolean,      required: true, default: false

  belongs_to :user

  def initialize(content, priority, user_id, receiver_login)
    @content        = content
    @priority       = priority
    @user_id        = user_id
    @receiver_login = receiver_login
  end

  def create
    self.content        = @content
    self.priority       = @priority
    self.user_id        = @user_id
    self.receiver_login = @receiver_login
    self.save
  end

end
