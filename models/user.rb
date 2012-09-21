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

  
    # Generating of token
  def self.new_token
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map { |r| r.to_a }.flatten
    Array.new(10).map { chars[rand(chars.size)] }.join
  end

  # friends.map! means that array of friends of certain user prepared to json parse
  def login?
    self.token ? true : self.update(token: User.new_token)
  end

  # When logout, token of certain user become nil
  def logout
    self.update(token: nil)   
  end

  # Registration
  def register
    self.save
  end

  # Property "deleted" of certain user become true (rights of "deleted" user is limited)
  def remove
    self.update(deleted: true)
  end

  # Property "deleted" of certain user become false (all rights are restored)
  def restore
    self.update(deleted: false)
  end

  # Search by certain fields in database (also can search by substring)
  def find(search_value)
    cases = [search_value.downcase, search_value.capitalize, search_value.upcase]
    users = Array.new

    cases.each do |value|
       users.concat(Array.new(User.all(:login.like     => "%#{value}%") |
                              User.all(:firstname.like => "%#{value}%") |
                              User.all(:lastname.like  => "%#{value}%")))
    end

    # Delete user which searching for other users
    users.delete(self)

    return false if users.empty?

    users.map! { |user| { login:     user.login,
                          firstname: user.firstname,
                          lastname:  user.lastname }}
    users = users.uniq
  end

  # Sending message of agree or disagree if user accept or declain friendship request
  # There is a special priority: 5 of friendship request message
  def add_friend(receiver)
      self.friends      << receiver
      receiver.friends  << self
      self.friends.save && receiver.friends.save
  end

  # Delete relations from both sides of friendship
  def delete_friend(receiver)
    self.friends.delete(receiver)
    receiver.friends.delete(self)
    self.friends.save && receiver.friends.save
  end

  def get_task
    tasks = Array.new(Task.all(read:           false,
                               receiver_login: self.login))
    return false if tasks.size == 0

    tasks.each do |task|
      task.update(read: true)
    end
      tasks
    end

  def add_task(receiver, options = {})
    priority = options['priority']
    content  = priority == 4 ? 'Add me to friends' : options['content']

    Task.new({ content:        content,
               priority:       priority,
               user_id:        self.id,
               receiver_login: receiver.login }).save
  end
end
