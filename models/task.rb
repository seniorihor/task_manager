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

  class << self
    def add(sender, receiver, options = {})
      priority = options['priority']
      content  = priority == 4 ? 'Add me to friends' : options['content']

      Task.new({ content:        content,
                 priority:       priority,
                 user_id:        sender.id,
                 receiver_login: receiver.login }).save
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
      Task.new(options).save
    end
  end
end
