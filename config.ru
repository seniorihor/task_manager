root = ::File.dirname(__FILE__)
require ::File.join( root, 'api/task_manager' )
run TaskManager.new
