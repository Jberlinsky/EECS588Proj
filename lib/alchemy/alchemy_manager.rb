require_relative './alchemy_api.rb'
require 'open-uri'

class Api::AlchemyManager < Api::BaseManager

  protected

  def execute_query(q, offset)
    client.keywords('url', URI::encode(q))
  end

  private

  def create_api_client(key)
    ::AlchemyAPI.new(key)
  end

  def result_set_cost
    1
  end

  def result_set_size
    1
  end
end
