require 'retry_block'
require 'retries'

class Api::BaseManager
  # Base class for managing a news API
  # News APIs are rate-limited, so this should control the API key used
  # Should also be able to estimate the number of results ("cost") for a given query

  # Collection of Api::ApiKey
  attr_accessor :api_keys

  # Memoized cache of query results
  # TODO move this to a database?
  attr_accessor :queries

  # API clients
  attr_accessor :clients

  def initialize(api_keys)
    @api_keys = Array(api_keys)
    @queries = {}
    @clients = {}
    ensure_api_keys_are_valid!
  end

  def query(q, offset = 0)
    cost = cost(q, offset)
    ensure_available_queries_for_api_key!(cost)
    result = execute_query_with_cache(q, offset)
    active_api_key.used(cost)
    result
  end

  def can_query?(expected_cost = result_set_cost || 1)
    @api_keys.any? { |k| k.has_uses?(expected_cost) }
  end

  protected

  def execute_query(q, offset)
    raise "Implement me"
  end

  def cost(query, offset)
    1 * result_set_cost
  end

  def ensure_available_queries_for_api_key!(cost)
    retry_block(fail_callback: -> { }, sleep: 0) do |attempt|
      cycle_api_keys!
      raise "API Key does not have enough uses left" unless active_api_key.has_uses?(cost)
    end
  end

  def cycle_api_keys!
    @api_keys = @api_keys.shuffle
  end

  def active_api_key
    @api_keys.first
  end

  def result_set_size
    raise "Implement me"
  end

  private

  def execute_query_with_cache(q, offset)
    with_retries(max_tries: 5) do
      @queries[query_key(q, offset)] ||= execute_query(q, offset)
    end
  end

  def ensure_api_keys_are_valid!
    unless @api_keys.map { |k| k.is_a?(Api::ApiKey) }.uniq == [true]
      raise ArgumentError, "API Keys must be instances of NewsApi::ApiKey"
    end
  end

  def query_key(q, offset)
    "#{q}#{offset.to_s}"
  end

  def client
    @clients[active_api_key.key.to_s] ||= create_api_client(active_api_key.key)
  end

  def create_api_client(key)
    raise "Implement me"
  end
end
