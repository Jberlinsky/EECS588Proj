require 'data_mapper'
require 'dm-migrations'

DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

require_relative './article.rb'
require_relative './api_key.rb'

DataMapper.finalize
DataMapper.auto_upgrade!
