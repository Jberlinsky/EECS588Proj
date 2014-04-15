class SourceSSLChecker
  attr_accessor :query

  def initialize(query)
    @query = query
  end

  def run!
    sources = Article.all.all(keyword: @query, is_ssl: nil)
    sources.each do |source|
      begin
        uri = URI.parse(source.url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 2
        http.use_ssl = true
        #http.enable_post_connection_check = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = File.join(".", "cacert.pem")

        http.start {
          http.request_get(uri.path) { |res|
            source.is_ssl = true
            source.save!
          }
        }
      rescue
        source.is_ssl = false
        source.save!
      end
    end
  end
end
