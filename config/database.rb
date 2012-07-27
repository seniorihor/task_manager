##
# A MySQL connection:
# DataMapper.setup(:default, 'mysql://user:password@localhost/the_database_name')
#
# # A Postgres connection:
# DataMapper.setup(:default, 'postgres://user:password@localhost/the_database_name')
#
# # A Sqlite3 connection
# DataMapper.setup(:default, "sqlite3://" + Padrino.root('db', "development.db"))
#

DataMapper.logger = logger
DataMapper::Property::String.length(20)
DataMapper::Property::Text.length(140)

case Padrino.env
  when :development then DataMapper.setup(:default, "sqlite3://" + Padrino.root('db', "task_manager_development.db"))
  when :production  then DataMapper.setup(:default, "sqlite3://" + Padrino.root('db', "task_manager_production.db"))
  when :test        then DataMapper.setup(:default, "sqlite3://" + Padrino.root('db', "task_manager_test.db"))
end
