require_relative 'user'
require_relative 'task'
require_relative 'friendship'

DataMapper.finalize
DataMapper.auto_upgrade!
