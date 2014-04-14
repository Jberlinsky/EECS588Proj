require 'page_rankr'
class Api::PageRankManager
  attr_accessor :pageranks, :backlinks

  def initialize
    @pageranks = {}
    @backlinks = {}
  end

  def get_pagerank(host)
    @pageranks[host] ||= PageRankr.ranks(host, :google).values.compact.inject(:+)
  end

  def get_backlinks(host)
    @backlinks[host] = PageRankr.backlinks(host, :google).values.compact.inject(:+)
  end

  class << self
    def get_pagerank(host)
      new.get_pagerank(host)
    end

    def get_backlinks(host)
      new.get_backlinks(host)
    end
  end
end
