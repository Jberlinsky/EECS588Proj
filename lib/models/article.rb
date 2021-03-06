ReadabilityParser.api_token = '555fc14395573afb9ae94c6fc666aa14347c6ccb'

class Article
  attr_accessor :depth

  include DataMapper::Resource

  property :id, Serial
  property :title, Text
  property :url, Text
  property :source, Text
  property :description, Text
  property :date, DateTime
  property :keyword, String
  property :alexa_ranking, Integer
  property :parsed_contents, Text
  property :is_ssl, Boolean

  validates_uniqueness_of :url

  QUORUM = 50

  def self.for_query(keyword)
    Article.all.all(keyword: keyword)
  end

  def self.destroy_without_quorum
    Article.all.map(&:keyword).uniq.each do |keyword|
      articles = Article.for_query(keyword)
      if articles.count < Article::QUORUM
        articles.map(&:destroy)
      end
    end
  end

  def self.without_alexa_ranking
    Article.all.all(alexa_ranking: nil)
  end

  def to_s
    source + " (#{date.to_s})"
  end

  def filename
    id.to_s
  end

  def content
    ReadabilityParser.parse(url).content
  rescue Exception
    nil
  end

  def contents
    parsed_contents || content
  end

  def full_description
    "#{to_s} : #{url}. Alexa score: #{alexa_ranking}"
  end
end
