require 'alexa'

class ArticleRanker

  class << self
    def perform(article_id)
      article = Article.get(article_id)
      article.alexa_ranking = rank(article.url)
      article.save
    end

    def rank(url)
      url_info(url).rank
    end

    private

    def url_info(url)
      client.url_info(url: url)
    end

    def client
      Alexa::Client.new(access_key_id: "AKIAIGCQAZSDAY3NPXTA", secret_access_key: "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")
    end
  end
end
