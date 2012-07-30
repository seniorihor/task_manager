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

  # Save user in database
  def add(login, password, firstname, lastname)
    self.login     = login
    self.password  = password
    self.firstname = firstname
    self.lastname  = lastname
    self.save
  end

  # Generating of token
  def self.new_token
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map { |r| r.to_a }.flatten
    Array.new(10).map { chars[rand(chars.size)] }.join
  end

  # friends.map! means that array of friends of certain user prepared to json parse
  def self.login(options = {})
    user = User.first(login: options['login'])

    return { login: { error: 'Invalid login or password' }}.to_json if user.nil?
    return { login: { error: 'Already in system' }}.to_json         if user.token

    if options['password'] == user.password
      user.token = self.new_token
      if user.save
        friends = Array.new(user.friends)
        friends.map! { |friend| { login:     friend.login,
                                  firstname: friend.firstname,
                                  lastname:  friend.lastname }}
        { login: { error:      'Success',
                   auth_token: user.token,
                   friends:    friends }}.to_json
      else
        { login: { error: 'Failure' }}.to_json
      end
    else
      { login: { error: 'Invalid login or password' }}.to_json
    end
  end

  # When logout, token of certain user become nil
  def self.logout(options = {})
    user       = User.first(token: options['auth_token'])
    user.token = nil if user

    if user.save
      { logout: { error: 'Success' }}.to_json
    else
      { logout: { error: 'Failure' }}.to_json
    end
  end

  # Registration
  def self.register(options = {})
    user = User.new
    if user.add(options['login'],
                options['password'],
                options['firstname'],
                options['lastname'])
      { register: { error: 'Success' }}.to_json
    else
      { register: { error: 'Failure' }}.to_json
    end
  end

  # Property deleted of certain user become true (rights of "deleted" user is limited)
  def self.remove(auth_token)
    user = User.first(token: auth_token)
    user.deleted = true

    if user.save
      { delete_user: { error: 'Success' }}.to_json
    else
      { delete_user: { error: 'Failure' }}.to_json
    end
  end

  # Property deleted of certain user become false (all rights are restored)
  def self.restore(auth_token)
    user = User.first(token: auth_token)
    user.deleted = false

    if user.save
      { restore_user: { error: 'Success' }}.to_json
    else
      { restore_user: { error: 'Failure' }}.to_json
    end
  end

  # Search by certain fields in database (also can search by substring)
  def self.find(options = {})
    search_value = options['search_value']
    return { find_user: { error: 'Need at least 2 characters' }}.to_json if search_value.size == 1

    users              = Array.new
    users_by_login     = Array.new(User.all(:login.like     => "%#{search_value}%"))
    users_by_firstname = Array.new(User.all(:firstname.like => "%#{search_value}%"))
    users_by_lastname  = Array.new(User.all(:lastname.like  => "%#{search_value}%"))

    users_by_login.each     { |user| users << user } unless users_by_login.empty?
    users_by_firstname.each { |user| users << user } unless users_by_firstname.empty?
    users_by_lastname.each  { |user| users << user } unless users_by_lastname.empty?

    users.delete(User.first(token: options['auth_token']))

    return { find_user: { error: 'No matching users' }}.to_json if users.empty?

    users.map! { |user| { login:     user.login,
                          firstname: user.firstname,
                          lastname:  user.lastname }}
    users = users.uniq

    { find_user: { error: 'Success',
                   users: users }}.to_json
  end

  # Sending message of agree or disagree if user accept or declain friendship request
  # There is a special priority: 5 of friendship request message
  def self.add_friend(options = {})
    sender   = User.first(token: options['auth_token'])
    receiver = User.first(login: options['receiver_login'])

    return { add_friend: { error: "User doesn't exist" }}.to_json                if receiver.nil?
    return { add_friend: { error: "You can't add yourself to friends" }}.to_json if sender == receiver
    return { add_friend: { error: 'User is deleted' }}.to_json                   if receiver.deleted

    invite_task = receiver.tasks.all(receiver_login: sender.login).last(priority: 4)

    return { add_friend: { error: "Invite doesn't exist" }}.to_json if invite_task.nil?

    if options['friendship'] == 'true'
      sender.friends   << receiver
      receiver.friends << sender

      if sender.friends.save && receiver.friends.save
        system_message = Task.new
        system_message.save_in_db("#{sender.firstname} #{sender.lastname} true", 5,sender.id, receiver.login)
        invite_task.destroy!
        { add_friend: { error:     'Success',
                        login:     receiver.login,
                        firstname: receiver.firstname,
                        lastname:  receiver.lastname }}.to_json
      else
        system_message = Task.new
        system_message.save_in_db("#{sender.firstname} #{sender.lastname} false", 5,sender.id, receiver.login)
        invite_task.destroy!
        { add_friend: { error: 'Success' }}.to_json
      end

    else
      system_message = Task.new
      system_message.save_in_db("#{sender.firstname} #{sender.lastname} false", 5,sender.id, receiver.login)
      invite_task.destroy!
      { add_friend: { error: 'Success' }}.to_json
    end
  end

  # Delete relations from both sides of friendship
  def self.delete_friend(options = {})
    sender   = User.first(token: options['auth_token'])
    receiver = User.first(login: options['receiver_login'])

    return { delete_friend: { error: "User doesn't exist" }}.to_json      if receiver.nil?
    return { delete_friend: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)

    sender.friends.delete(receiver)
    receiver.friends.delete(sender)

    if sender.friends.save && receiver.friends.save
      system_message = Task.new
      system_message.save_in_db('true', 6, sender.id, receiver.login)
      { delete_friend: { error: 'Success' }}.to_json
    else
      { delete_friend: { error: 'Failure' }}.to_json
    end
  end

  def self.friends_online(auth_token)
    user    = User.first(token: auth_token)
    friends = user.friends.select { |friend| friend.token }
    friends = friends.map! { |friend| { login:     friend.login,
                                        firstname: friend.firstname,
                                        lastname:  friend.lastname }}
    { friends_online: { error:   'Success',
                        friends: friends }}.to_json
  end
end
