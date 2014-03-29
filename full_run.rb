require_relative './lib/runner.rb'
require_relative './lib/parser.rb'

QUERY = 'Boston Marathon Bombing'

bing_api_keys = [Api::ApiKey.new('8C+6GKN/UHrCiYlVhZ12J2wpTKhpyQZ3VneTZHp2+Qg', 791)]
alchemy_api_keys = [Api::ApiKey.new('d753d574a4bfb0630d034b8b72575e9b03b1a574', 500)]

Runner.new(QUERY, bing_api_keys).run!
Parser.new(QUERY, alchemy_api_keys).run!
