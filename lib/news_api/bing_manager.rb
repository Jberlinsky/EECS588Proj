require 'searchbing'

class NewsApi::BingManager < Api::BaseManager

  def result_set_size
    50
  end

  protected

  def execute_query(q, offset)
    begin
      client.search(q, offset)
    rescue JSON::ParserError
      raise "Need new Bing tokens :("
    end
  end

  private

  def create_api_client(key)
    Bing.new(key, result_set_size, 'News')
  end

  def result_set_cost
    1
  end

end
