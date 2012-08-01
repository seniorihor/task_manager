class TaskManager < Sinatra::Application

  # Filters
  before do
    content_type :json
  end

  # Protected means that users without rights, can't receive response from certain methods
  # @auth - indicator of authentication
  before '/protected/*' do
    json_data = request.body.read

    if json_data.empty?
      @auth = false
    else
      @protected_hash = to_hash(json_data)
      user = User.first(token: @protected_hash['taskmanager']['auth_token'])

      if user.nil? || user.token.nil?
        @auth = false
      elsif user.deleted
        @auth         = false
        @restore_auth = true
      else
        @auth = true
      end
    end
  end

  # Routes
  # Login user
  post '/login' do
    @hash = to_hash(request.body.read)

    halt 400, { login: { error: 'Empty fields' }}.to_json if empty_fields?(@hash['taskmanager'])

    user     = User.first(login: @hash['taskmanager']['login'])
    password = @hash['taskmanager']['password']

    halt 403, { login: { error: 'Invalid login or password' }}.to_json if user.nil? || password != user.password
    halt 403, { login: { error: 'Already in system' }}.to_json         if user.token

    if User.login(user, password)
      halt 200, { login: { error:      'Success',
                           auth_token: user.token,
                           friends:    Array.new(user.friends) }}.to_json
    else
      halt 424, { login: { error: 'Failure' }}.to_json
    end
  end

  # Logout user
  post '/protected/logout' do
    halt 403, { logout: { error: '403 Forbidden' }}.to_json unless @auth

    User.logout(user_by_token)
  end

  # Register user
  post '/register' do
    @hash = to_hash(request.body.read)
    halt 400, { register: { error: 'Empty fields' }}.to_json if empty_fields?(@hash['taskmanager'])

    if login_exists?(@hash['taskmanager']['login'])
      halt 403, { register: { error: 'Login exists' }}.to_json
    else
      User.register(@hash['taskmanager'])
    end
  end

  # Delete user
  post '/protected/delete_user' do
    halt 403, { delete_user: { error: '403 Forbidden' }}.to_json unless @auth

    User.remove(user_by_token)
  end

  # Restore user
  post '/protected/restore_user' do
    halt 403, { restore_user: { error: '403 Forbidden' }}.to_json unless @restore_auth

    User.restore(user_by_token)
  end

  # Find user
  post '/protected/find_user' do
    halt 403, { find_user: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { find_user: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    search_value = @protected_hash['taskmanager']['search_value']
    halt 411, { find_user: { error: 'Need at least 2 characters' }}.to_json if search_value.size == 1

    User.find(user_by_token, search_value)
  end

  # Add friend
  post '/protected/add_friend' do
    halt 403, { add_friend: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { add_friend: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    sender   = user_by_token
    receiver = user_by_receiver_login

    halt 403, { add_friend: { error: "User doesn't exist" }}.to_json                if receiver.nil?
    halt 403, { add_friend: { error: "You can't add yourself to friends" }}.to_json if sender == receiver
    halt 403, { add_friend: { error: 'User is deleted' }}.to_json                   if receiver.deleted

    case @protected_hash['taskmanager']['priority']
    when 4
      Task.add(sender, receiver, @protected_hash['taskmanager'])
    when 5
      User.add_friend(sender, receiver, @protected_hash['taskmanager'])
    else
      halt 406, { add_friend: { error: 'Wrong priority' }}.to_json
    end
  end

  # Delete friend
  post '/protected/delete_friend' do
    halt 403, { delete_friend: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { delete_friend: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    sender   = user_by_token
    receiver = user_by_receiver_login

    halt 403, { delete_friend: { error: "User doesn't exist" }}.to_json      if receiver.nil?
    halt 403, { delete_friend: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)

    User.delete_friend(sender, receiver)
  end

  # Create new task
  post '/protected/new_task' do
    halt 403, { new_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { new_task: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    sender   = user_by_token
    receiver = user_by_receiver_login
    priority = @protected_hash['taskmanager']['priority']

    halt 403, { new_task: { error: "User doesn't exist" }}.to_json    if receiver.nil?
    halt 403, { new_task: { error: "You can't be receiver" }}.to_json if sender == receiver
    halt 403, { new_task: { error: 'User is deleted' }}.to_json       if receiver.deleted
    halt 403, { add_friend: { error: 'Already friend' }}.to_json      if sender.friends.include?(receiver) &&
                                                                         priority == 4

    case priority
    when 1..3
      halt 403, { new_task: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)
    else
      halt 406, { new_task: { error: 'Wrong priority' }}.to_json
    end

    Task.add(sender, receiver, @protected_hash['taskmanager'])
  end

  # Delete task
  post '/protected/delete_task' do
    halt 403, { delete_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { delete_task: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    task = Task.all(receiver_login: user_by_token.login).get(@protected_hash['taskmanager']['task_id'])

    halt 403, { delete_task: { error: "Task doesn't exist" }}.to_json if task.nil?

    Task.delete(task)
  end

  # List all tasks
  post '/protected/get_task' do
    halt 403, { get_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { get_task: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    Task.get(user_by_token)
  end
end
