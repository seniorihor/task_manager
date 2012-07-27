# Join table which include relations between two users (id to id)
class Friendship
  include DataMapper::Resource

  belongs_to :source, 'User', key: true
  belongs_to :target, 'User', key: true
end

DataMapper.finalize
DataMapper.auto_upgrade!