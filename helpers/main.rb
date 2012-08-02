require 'json'

module CommonHelper
  # Parse of JSON request
  def to_hash(json_data)
    JSON.parse(json_data)
  end

  # Method name explain everything
  def login_exists?(login)
    User.first(login: login).nil? ? false : true
  end

  # Check for empty fields
  def empty_fields?(options = {})
    options.each_value do |field|
      return true if field.to_s.empty?
    end
    false
  end

  def user_by_token
    User.first(token: @protected_hash['taskmanager']['auth_token'])
  end

  def user_by_receiver_login
    User.first(login: @protected_hash['taskmanager']['receiver_login'])
  end

  def delete_temporary_tasks(login)
    add_friend_tasks    = Array.new(Task.all(receiver_login: login,
                                             read:           true,
                                             priority:       5))
    delete_friend_tasks = Array.new(Task.all(receiver_login: login,
                                             read:           true,
                                             priority:       6))
    add_friend_tasks.each    { |task| task.destroy! } unless add_friend_tasks.empty?
    delete_friend_tasks.each { |task| task.destroy! } unless delete_friend_tasks.empty?
  end
end
