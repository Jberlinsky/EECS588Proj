require 'rubygems'
require 'benchmark'
require 'pry'

require_relative './api/api.rb'

class Runner
  PAGES_TO_FETCH = 150
# Access News API for topic
# For every result (preferrably exhausting pagination if possible):
#   Get the content of the news article
#   Run it through keyword distillation
#   Group by major keywords. Make sure to store news source, URL, and publication date
# For every set of major keywords:
#   Construct a dependency graph where dependencies are denoted by an article being time-after another.
#   Store the dependency graph
#
  attr_accessor :api_keys, :query, :articles

  def initialize(query, api_keys)
    @api_keys = Array(api_keys)
    @query = query
  end

  def run!
    fetch_all_articles
    dump_articles_to_json!
  end

  private

  def dump_articles_to_json!
    File.open("./#{@query.gsub(' ', '_')}.json", 'w') { |f| f.write(@articles.to_json) }
  end

  def fetch_all_articles
    @articles ||= []
    PAGES_TO_FETCH.times do |i|
      (retrieve_article_slice(@query, i) and i += 1) while bing.can_query?
    end
  end

  def retrieve_article_slice(q, i)
    result_set = bing.query(q, i*bing.result_set_size)
    result_set[0][:News].each do |result|
      @articles << {
        title: result[:Title],
        url: result[:Url],
        source: result[:Source],
        description: result[:Description],
        date: result[:Date]
      }
    end
  end

  def bing
    @bing ||= NewsApi::BingManager.new(@api_keys)
  end
end

