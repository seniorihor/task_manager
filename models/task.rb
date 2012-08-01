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

    def save_in_db(content, priority, user_id, receiver_login)
      self.content        = content
      self.priority       = priority
      self.user_id        = user_id
      self.receiver_login = receiver_login
      self.save
    end

  class << self
    def add(sender, receiver, options = {})
      priority = options['priority']
      content  = priority == 4 ? 'Add me to friends' : options['content']

      task = Task.new
      task.save_in_db(content, priority, sender.id, receiver.login)
    end

    def delete(task)
      task.destroy!
    end

    def get(user)
      tasks      = Array.new(Task.all(read: false, receiver_login: user.login))

      return false if tasks.size == 0

      tasks.each do |task|
        task.update(read: true)
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
      tasks
    end
  end
end
