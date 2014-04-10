require_relative './lib/runner.rb'
require_relative './lib/parser.rb'

QUERY = 'Boston Marathon Bombing'

bing_api_keys = [
  Api::ApiKey.new('4s/w/nR7qqkEPePsOIWMGTPrxzE2zenuw8FDpu8kqwc', 4_800)
]
alchemy_api_keys = [
  Api::ApiKey.new('d753d574a4bfb0630d034b8b72575e9b03b1a574', 300),
  Api::ApiKey.new('1b626a3e33ec3bd617d1859b7c6e846cdfe38387', 500)
]

#Runner.new('Boston Marathon Bombing', bing_api_keys).run!
#Runner.new('Enron', bing_api_keys).run!
Parser.new('Boston Marathon Bombing', alchemy_api_keys).run!(true)
