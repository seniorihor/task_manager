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
      tasks = Array.new(Task.all(read:           false,
                                 receiver_login: user.login))
      return false if tasks.size == 0

      tasks.each do |task|
        task.update(read: true)
      end
      tasks
    end

    def system_message(options = {})
      task = Task.new
      task.save_in_db(options['content'],
                      options['priority'],
                      options['user_id'],
                      options['receiver_login'])
    end
  end
end
