%w(dm-core dm-sqlite-adapter dm-validations dm-migrations dm-timestamps dm-types).each { |gem| require gem }
require_relative 'data_mapper_conf'
