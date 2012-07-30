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

  def save_in_db
    self.content        = @content
    self.priority       = @priority
    self.user_id        = @user_id
    self.receiver_login = @receiver_login
    self.save
  end

  def self.add(options = {})

    auth_token     = options['auth_token']
    receiver_login = options['receiver_login']
    content        = options['content']
    priority       = options['priority']

    if priority == 4 then content = 'Add me to friends' end

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

    task = Task.new(content, priority, sender.id, User.first(login: receiver_login).login)

    if task.save_in_db && priority == 4
      { add_friend: { error: 'Success' }}.to_json
    elsif task.save_in_db
      { new_task: { error: 'Success' }}.to_json
    else
      { new_task: { error: 'Failure' }}.to_json
    end
  end

  def self.delete(options = {})
    return { delete_task: { error: 'Empty fields' }}.to_json if options['task_id'].nil?

    user = User.first(token: options['auth_token'])
    task = Task.all(receiver_login: user.login).get(options['task_id'])

    return { delete_task: { error: "Task doesn't exist" }}.to_json if task.nil?

    if task.destroy!
      { delete_task: { error: 'Success' }}.to_json
    else
      { delete_task: { error: 'Failure' }}.to_json
    end
  end

  def self.get(options = {})
    user       = User.first(token: options['auth_token'])
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
