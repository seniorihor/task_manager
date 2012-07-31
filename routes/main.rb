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

    User.login(@hash['taskmanager'])
  end

  # Logout user
  post '/protected/logout' do
    halt 403, { logout: { error: '403 Forbidden' }}.to_json unless @auth

    User.logout(@protected_hash['taskmanager'])
  end

  # Register user
  post '/register' do
    @hash = to_hash(request.body.read)
    halt 400, { register: { error: 'Empty fields' }}.to_json if empty_fields?(@hash['taskmanager'])

    if login_exists?(@hash['taskmanager'])
      halt 500, { register: { error: 'Login exists' }}.to_json
    else
      User.register(@hash['taskmanager'])
    end
  end

  # Delete user
  post '/protected/delete_user' do
    halt 403, { delete_user: { error: '403 Forbidden' }}.to_json unless @auth

    User.remove(@protected_hash['taskmanager']['auth_token'])
  end

  # Restore user
  post '/protected/restore_user' do
    halt 403, { restore_user: { error: '403 Forbidden' }}.to_json unless @restore_auth

    User.restore(@protected_hash['taskmanager']['auth_token'])
  end

  # Find user
  post '/protected/find_user' do
    halt 403, { find_user: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { find_user: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    User.find(@protected_hash['taskmanager'])
  end

  # Add friend
  post '/protected/add_friend' do
    halt 403, { add_friend: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { add_friend: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    case @protected_hash['taskmanager']['priority']
    when 4
      Task.add(@protected_hash['taskmanager'])
    when 5
      User.add_friend(@protected_hash['taskmanager'])
    else
      halt 406, { add_friend: { error: 'Wrong priority' }}.to_json
    end
  end

  # Delete friend
  post '/protected/delete_friend' do
    halt 403, { delete_friend: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { delete_friend: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    User.delete_friend(@protected_hash['taskmanager'])
  end

  # Create new task
  post '/protected/new_task' do
    halt 403, { new_task: { error: '403 Forbidden' }}.to_json  unless @auth
    halt 400, { new_task: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    case @protected_hash['taskmanager']['priority']
    when 1..3
    else
      halt 406, { new_task: { error: 'Wrong priority' }}.to_json
    end

    Task.add(@protected_hash['taskmanager'])
  end

  # Delete task
  post '/protected/delete_task' do
    halt 403, { delete_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { delete_task: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    Task.delete(@protected_hash['taskmanager'])
  end

  # List all tasks
  post '/protected/get_task' do
    halt 403, { get_task: { error: '403 Forbidden' }}.to_json unless @auth
    halt 400, { get_task: { error: 'Empty fields' }}.to_json if empty_fields?(@protected_hash['taskmanager'])

    Task.get(@protected_hash['taskmanager'])
  end
end
