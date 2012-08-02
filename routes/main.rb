class TaskManager < Sinatra::Base

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

    if User.login(user)
      friends = Array.new(user.friends)
      friends.map! { |friend| { login:     friend.login,
                                firstname: friend.firstname,
                                lastname:  friend.lastname }}
      halt 200, { login: { error:      'Success',
                           auth_token: user.token,
                           friends:    friends }}.to_json
    else
      halt 424, { login: { error: 'Failure' }}.to_json
    end
  end

  # Logout user
  post '/protected/logout' do
    halt 403, { logout: { error: '403 Forbidden' }}.to_json unless @auth

    if User.logout(user_by_token)
      halt 200, { logout: { error: 'Success' }}.to_json
    else
      halt 424, { logout: { error: 'Failure' }}.to_json
    end
  end

  # Register user
  post '/register' do
    @hash = to_hash(request.body.read)
    halt 400, { register: { error: 'Empty fields' }}.to_json if empty_fields?(@hash['taskmanager'])

    if login_exists?(@hash['taskmanager']['login'])
      halt 403, { register: { error: 'Login exists' }}.to_json
    else
      if User.register(@hash['taskmanager'])
        halt 200, { register: { error: 'Success' }}.to_json
      else
        halt 424, { register: { error: 'Failure' }}.to_json
      end
    end
  end

  # Delete user
  post '/protected/delete_user' do
    halt 403, { delete_user: { error: '403 Forbidden' }}.to_json unless @auth

    if User.remove(user_by_token)
      halt 200, { delete_user: { error: 'Success' }}.to_json
    else
      halt 424, { delete_user: { error: 'Failure' }}.to_json
    end
  end

  # Restore user
  post '/protected/restore_user' do
    halt 403, { restore_user: { error: '403 Forbidden' }}.to_json unless @restore_auth

    if User.restore(user_by_token)
      halt 200, { restore_user: { error: 'Success' }}.to_json
    else
      halt 424, { restore_user: { error: 'Failure' }}.to_json
    end
  end

  # Find user
  post '/protected/find_user' do
    halt 403, { find_user: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { find_user: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    search_value = @protected_hash['taskmanager']['search_value']
    halt 411, { find_user: { error: 'Need at least 2 characters' }}.to_json if search_value.size == 1

    unless users = User.find(user_by_token, search_value)
      halt 500, { find_user: { error: 'No matching users' }}.to_json
    else
      { find_user: { error: 'Success',
                     users: users }}.to_json
    end
  end

  # Add friend
  post '/protected/add_friend' do
    halt 403, { add_friend: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { add_friend: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    sender   = user_by_token
    receiver = user_by_receiver_login
    priority = @protected_hash['taskmanager']['priority']

    halt 403, { add_friend: { error: "User doesn't exist" }}.to_json                if receiver.nil?
    halt 403, { add_friend: { error: "You can't add yourself to friends" }}.to_json if sender == receiver
    halt 403, { add_friend: { error: 'User is deleted' }}.to_json                   if receiver.deleted
    halt 403, { add_friend: { error: 'Already friend' }}.to_json                    if sender.friends.include?(receiver)

    invite_task_sender   = sender.tasks.all(receiver_login: receiver.login).last(priority: 4)
    invite_task_receiver = receiver.tasks.all(receiver_login: sender.login).last(priority: 4)

    halt 403, { add_friend: { error: 'Invite exists' }}.to_json                  if invite_task_sender

    case priority
    when 4
      halt 403, { add_friend: { error: 'You have invite from this user' }}.to_json if invite_task_receiver

      if Task.add(sender, receiver, @protected_hash['taskmanager'])
        halt 200, { add_friend: { error: 'Success' }}.to_json
      else
        halt 424, { add_friend: { error: 'Failure' }}.to_json
      end
    when 5
      halt 403, { add_friend: { error: "Invite doesn't exist" }}.to_json if invite_task_receiver.nil?
      if @protected_hash['taskmanager']['friendship'] == 'true'
        if User.add_friend(sender, receiver)
          Task.system_message({ content:        "#{sender.firstname} #{sender.lastname} true",
                                priority:       5,
                                user_id:        sender.id,
                                receiver_login: receiver.login })
          invite_task_receiver.destroy!
          halt 200, { add_friend: { error:     'Success',
                                    login:     receiver.login,
                                    firstname: receiver.firstname,
                                    lastname:  receiver.lastname }}.to_json
        else
          Task.system_message({ content:        "#{sender.firstname} #{sender.lastname} false",
                                priority:       5,
                                user_id:        sender.id,
                                receiver_login: receiver.login })
          invite_task.destroy!
          halt 424, { add_friend: { error: 'Failure' }}.to_json
        end
      else
        Task.system_message({ content:        "#{sender.firstname} #{sender.lastname} false",
                              priority:       5,
                              user_id:        sender.id,
                              receiver_login: receiver.login })
        invite_task_receiver.destroy!
        { add_friend: { error: 'Success' }}.to_json
      end

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

    if User.delete_friend(sender, receiver)
      Task.system_message({ content:        'true',
                            priority:       6,
                            user_id:        sender.id,
                            receiver_login: receiver.login })
      halt 200, { delete_friend: { error: 'Success' }}.to_json
    else
      halt 424, { delete_friend: { error: 'Failure' }}.to_json
    end
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

    case priority
    when 1..3
      halt 403, { new_task: { error: 'This is not your friend' }}.to_json unless sender.friends.include?(receiver)
    else
      halt 406, { new_task: { error: 'Wrong priority' }}.to_json
    end

    if Task.add(sender, receiver, @protected_hash['taskmanager'])
      halt 200, { new_task: { error: 'Success' }}.to_json
    else
      halt 424, { new_task: { error: 'Failure' }}.to_json
    end
  end

  # Delete task
  post '/protected/delete_task' do
    halt 403, { delete_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { delete_task: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    task = Task.all(receiver_login: user_by_token.login).get(@protected_hash['taskmanager']['task_id'])

    halt 403, { delete_task: { error: "Task doesn't exist" }}.to_json if task.nil?

    if Task.delete(task)
      halt 200, { delete_task: { error: 'Success' }}.to_json
    else
      halt 424, { delete_task: { error: 'Failure' }}.to_json
    end
  end

  # List all tasks
  post '/protected/get_task' do
    halt 403, { get_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { get_task: { error: 'Empty fields' }}.to_json  if empty_fields?(@protected_hash['taskmanager'])

    unless tasks = Task.get(user_by_token)
      halt 200, { get_task: { error:    'Success',
                              quantity: 0 }}.to_json
    else
      tasks.map! { |task| { id:         task.id,
                            content:    task.content,
                            priority:   task.priority,
                            user_login: User.get(task.user_id).login,
                            created_at: task.created_at.strftime('%d.%m.%Y %H:%M') }} # 12.12.2012 12:12

      delete_temporary_tasks(user_by_token.login)

      halt 200, { get_task: { error:    'Success',
                              quantity: tasks.size,
                              tasks:    tasks }}.to_json
    end
  end
end
