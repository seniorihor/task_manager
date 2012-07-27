# Helpers
helpers do

  # Generating of token
  def new_token
    chars = ['A'..'Z', 'a'..'z', '0'..'9'].map { |r| r.to_a }.flatten
    Array.new(10).map { chars[rand(chars.size)] }.join
  end

  # Parse of JSON request
  def to_hash(json_data)
    JSON.parse(json_data)
  end

  # Method name explain everything
  def login_exists?(login)
    User.first(login: login).nil? ? false : true
  end

  # friends.map! means that array of friends of certain user prepared to json parse
  def login(login, password)
    user = User.first(login: login)

    return { login: { error: 'Invalid login or password' }}.to_json if user.nil?
    return { login: { error: 'Already in system' }}.to_json         if user.token

    if password == user.password
      user.token = new_token
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
  def logout(auth_token)
    user       = User.first(token: auth_token)
    user.token = nil if user

    if user.save
      { logout: { error: 'Success' }}.to_json
    else
      { logout: { error: 'Failure' }}.to_json
    end
  end

  # Registration
  def add_new_user(login, password, firstname, lastname)
    return { register: { error: 'Empty fields' }}.to_json if login.empty?     ||
                                                             password.empty?  ||
                                                             firstname.empty? ||
                                                             lastname.empty?

    user           = User.new
    user.login     = login
    user.password  = password
    user.firstname = firstname
    user.lastname  = lastname

    if user.save
      { register: { error: 'Success' }}.to_json
    else
      { register: { error: 'Failure' }}.to_json
    end
  end

  # Property deleted of certain user become true (rights of "deleted" user is limited)
  def delete_user(auth_token)
    user = User.first(token: auth_token)
    user.deleted = true

    if user.save
      { delete_user: { error: 'Success' }}.to_json
    else
      { delete_user: { error: 'Failure' }}.to_json
    end
  end

  # Property deleted of certain user become false (all rights are restored)
  def restore_user(auth_token)
    user = User.first(token: auth_token)
    user.deleted = false

    if user.save
      { restore_user: { error: 'Success' }}.to_json
    else
      { restore_user: { error: 'Failure' }}.to_json
    end
  end

  # Search by certain fields in database (also can search by substring)
  def find_user(auth_token, search_value)
    return { find_user: { error: 'Empty fields' }}.to_json               if search_value.empty?
    return { find_user: { error: 'Need at least 2 characters' }}.to_json if search_value.size == 1

    users              = Array.new
    users_by_login     = Array.new(User.all(:login.like     => "%#{search_value}%"))
    users_by_firstname = Array.new(User.all(:firstname.like => "%#{search_value}%"))
    users_by_lastname  = Array.new(User.all(:lastname.like  => "%#{search_value}%"))

    users_by_login.each     { |user| users << user } unless users_by_login.empty?
    users_by_firstname.each { |user| users << user } unless users_by_firstname.empty?
    users_by_lastname.each  { |user| users << user } unless users_by_lastname.empty?

    users.delete(User.first(token: auth_token))

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
  def add_friend(auth_token, receiver_login, friendship)
    return { add_friend: { error: 'Empty fields' }}.to_json if receiver_login.empty? ||
                                                               friendship.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return { add_friend: { error: "User doesn't exist" }}.to_json                if receiver.nil?
    return { add_friend: { error: "You can't add yourself to friends" }}.to_json if sender == receiver
    return { add_friend: { error: 'User is deleted' }}.to_json                   if receiver.deleted

    invite_task = receiver.tasks.all(receiver_login: sender.login).last(priority: 4)

    return { add_friend: { error: "Invite doesn't exist" }}.to_json if invite_task.nil?

    if friendship == 'true'
      sender.friends   << receiver
      receiver.friends << sender

      if sender.friends.save && receiver.friends.save
        add_new_task(sender.token, receiver.login, "#{sender.firstname} #{sender.lastname} true", 5)
        invite_task.destroy!
        { add_friend: { error:     'Success',
                        login:     receiver.login,
                        firstname: receiver.firstname,
                        lastname:  receiver.lastname }}.to_json
      else
        add_new_task(sender.token, receiver.login, "#{sender.firstname} #{sender.lastname} false", 5)
        invite_task.destroy!
        { add_friend: { error: 'Success' }}.to_json
      end

    else
      add_new_task(sender.token, receiver.login, "#{sender.firstname} #{sender.lastname} false", 5)
      invite_task.destroy!
      { add_friend: { error: 'Success' }}.to_json
    end
  end

  # Delete relations from both sides of friendship
  def delete_friend(auth_token, receiver_login)
    return { delete_friend: { error: 'Empty fields' }}.to_json if receiver_login.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return { delete_friend: { error: "User doesn't exist" }}.to_json      if receiver.nil?
    return { delete_friend: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)

    sender.friends.delete(receiver)
    receiver.friends.delete(sender)

    if sender.friends.save && receiver.friends.save
      add_new_task(sender.token, receiver.login, 'true', 6)
      { delete_friend: { error: 'Success' }}.to_json
    else
      { delete_friend: { error: 'Failure' }}.to_json
    end
  end

  def friends_online(auth_token)
    user    = User.first(token: auth_token)
    friends = user.friends.select { |friend| friend.token }
    friends = friends.map! { |friend| { login:     friend.login,
                                        firstname: friend.firstname,
                                        lastname:  friend.lastname }}
    { friends_online: { error:   'Success',
                        friends: friends }}.to_json
  end

  def add_new_task(auth_token, receiver_login, content, priority)
    return { new_task: { error: 'Empty fields' }}.to_json if content.empty? ||
                                                             priority.nil?  ||
                                                             receiver_login.empty?

    sender   = User.first(token: auth_token)
    receiver = User.first(login: receiver_login)

    return { new_task: { error: "User doesn't exist" }}.to_json    if receiver.nil?
    return { new_task: { error: "You can't be receiver" }}.to_json if sender == receiver
    return { new_task: { error: 'User is deleted' }}.to_json       if receiver.deleted

    case priority
    when 1..3
      return { new_task: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)
    end

    return { add_friend: { error: 'Already friend' }}.to_json if sender.friends.include?(receiver) &&
                                                                 priority == 4

    invite_task_sender   = sender.tasks.all(receiver_login: receiver.login).last(priority: 4)
    invite_task_receiver = receiver.tasks.all(receiver_login: sender.login).last(priority: 4)

    return { add_friend: { error: 'Invite exists' }}.to_json                  if invite_task_sender
    return { add_friend: { error: 'You have invite from this user' }}.to_json if invite_task_receiver &&
                                                                                 priority == 4

    task                = Task.new
    task.content        = content
    task.priority       = priority
    task.user_id        = sender.id
    task.receiver_login = User.first(login: receiver_login).login

    if task.save && priority == 4
      { add_friend: { error: 'Success' }}.to_json
    elsif task.save
      { new_task: { error: 'Success' }}.to_json
    else
      { new_task: { error: 'Failure' }}.to_json
    end
  end

  def delete_task(auth_token, task_id)
    return { delete_task: { error: 'Empty fields' }}.to_json if task_id.nil?

    user = User.first(token: auth_token)
    task = Task.all(receiver_login: user.login).get(task_id)

    return { delete_task: { error: "Task doesn't exist" }}.to_json if task.nil?

    if task.destroy!
      { delete_task: { error: 'Success' }}.to_json
    else
      { delete_task: { error: 'Failure' }}.to_json
    end
  end

  # A method which return only new tasks of certain user
  # Also method delete temporary task like invites and response on them
  def get_task(auth_token)
    user       = User.first(token: auth_token)
    collection = Task.all(read: false, receiver_login: user.login)

    tasks    = Array.new(collection)
    quantity = tasks.size

    return { get_task: { error:    'Success',
                         quantity: quantity }}.to_json if quantity == 0

    tasks.each do |task|
         task.read = true
         task.save
    end

    tasks.map! { |task| { id:         task.id,
                          content:    task.content,
                      	  priority:   task.priority,
                      	  user_login: User.get(task.user_id).login,
                      	  created_at: task.created_at.strftime('%d.%m.%Y %H:%M') }} # 12.12.2012 12:12

    # Delete all temporary tasks
    add_friend_tasks    = Array.new(Task.all(receiver_login: user.login, read: true, priority: 5))
    delete_friend_tasks = Array.new(Task.all(receiver_login: user.login, read: true, priority: 6))
    add_friend_tasks.each    { |task| task.destroy! } unless add_friend_tasks.empty?
    delete_friend_tasks.each { |task| task.destroy! } unless delete_friend_tasks.empty?

    { get_task: { error:    'Success',
                  quantity: quantity,
                  tasks:    tasks }}.to_json
  end
end