require_relative './lib/runner.rb'
require_relative './lib/parser.rb'

bing_api_keys = [
  Api::ApiKey.new('4s/w/nR7qqkEPePsOIWMGTPrxzE2zenuw8FDpu8kqwc', 4_800)
]
alchemy_api_keys = [
  Api::ApiKey.new('d753d574a4bfb0630d034b8b72575e9b03b1a574', 300),
  Api::ApiKey.new('1b626a3e33ec3bd617d1859b7c6e846cdfe38387', 500)
]

QUERIES = [
  'Boston Marathon Bombing',
  'Enron',
  'MH370',
  'Sandy Hook Elementary'
]

#QUERIES.each do |query|
#  Runner.new(query, bing_api_keys).run!
#end

QUERIES.each do |query|
  Parser.new(query, alchemy_api_keys).run!
end
