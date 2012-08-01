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

  class << self
    # Generating of token
    def new_token
      chars = ['A'..'Z', 'a'..'z', '0'..'9'].map { |r| r.to_a }.flatten
      Array.new(10).map { chars[rand(chars.size)] }.join
    end

    # friends.map! means that array of friends of certain user prepared to json parse
    def login(user)
      user.update(token: self.new_token)
    end

    # When logout, token of certain user become nil
    def logout(user)
      user.update(token: nil) if user
    end

    # Registration
    def register(options = {})
      User.new(options).save
    end

    # Property deleted of certain user become true (rights of "deleted" user is limited)
    def remove(user)
      user.update(deleted: true)
    end

    # Property deleted of certain user become false (all rights are restored)
    def restore(user)
      user.update(deleted: false)
    end

    # Search by certain fields in database (also can search by substring)
    def find(user, search_value)
      users              = Array.new
      users_by_login     = Array.new(User.all(:login.like     => "%#{search_value}%"))
      users_by_firstname = Array.new(User.all(:firstname.like => "%#{search_value}%"))
      users_by_lastname  = Array.new(User.all(:lastname.like  => "%#{search_value}%"))

      users_by_login.each     { |user| users << user } unless users_by_login.empty?
      users_by_firstname.each { |user| users << user } unless users_by_firstname.empty?
      users_by_lastname.each  { |user| users << user } unless users_by_lastname.empty?

      # Delete user which searching for other users
      users.delete(user)

      return false if users.empty?

      users.map! { |user| { login:     user.login,
                            firstname: user.firstname,
                            lastname:  user.lastname }}
      users = users.uniq
    end

    # Sending message of agree or disagree if user accept or declain friendship request
    # There is a special priority: 5 of friendship request message
    def add_friend(sender, receiver)
        sender.friends   << receiver
        receiver.friends << sender
        sender.friends.save && receiver.friends.save
    end

    # Delete relations from both sides of friendship
    def delete_friend(sender, receiver)
      sender.friends.delete(receiver)
      receiver.friends.delete(sender)
      sender.friends.save && receiver.friends.save
    end
  end
end
