class ArticleContentDownloader
  attr_accessor :query

  def initialize(query)
    @query = query
  end

  def run!
    articles = Article.all.all(keyword: query, parsed_contents: nil)
    articles.each do |article|
      begin
        article.parsed_contents = article.content
        article.save!
      rescue ReadabilityParser::Error::ClientError => ex
        binding.pry
        status_code = ex.message.split(' ').last.to_i
        if status_code == 504
          article.destroy
        end
      rescue ReadabilityParser::Error::BadRequest => ex
        binding.pry
        article.destroy
      rescue JSON::ParserError => ex
        binding.pry
        next
      rescue Exception => ex
        puts "ERROR: #{ex.message}"
        next
      end
    end
  end
end
