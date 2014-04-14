require 'rubygems'
require 'benchmark'
require 'readability_parser'
require 'pry'

require_relative './api/api.rb'

class Runner
  class NoMoreResultsAdded < StandardError ; end

  PAGES_TO_FETCH = 300
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
    puts "Working on query '#{@query}'"
    fetch_all_articles
  end

  private

  def fetch_all_articles
    @articles ||= []
    failures_allowed = 3
    (0...PAGES_TO_FETCH).each do |i|
      begin
        (retrieve_article_slice(@query, i)) if bing.can_query?
      rescue Runner::NoMoreResultsAdded
        failures_allowed -= 1
        break if failures_allowed == 0
      end
    end
  end

  def retrieve_article_slice(q, i)
    puts "Getting articles #{i*bing.result_set_size} - #{(i+1)*bing.result_set_size}"
    result_set = bing.query(q, i*bing.result_set_size)
    initial_article_count = Article.count
    result_set[0][:News].each do |result|
      a = Article.new(
        title: result[:Title],
        url: result[:Url],
        source: result[:Source],
        description: result[:Description],
        date: DateTime.parse(result[:Date]),
        keyword: q
      )
      a.save
    end
    raise Runner::NoMoreResultsAdded if Article.count == initial_article_count
  end

  def bing
    @bing ||= NewsApi::BingManager.new(@api_keys)
  end
end

