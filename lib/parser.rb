require 'json'
require 'pry'
require 'rgl/adjacency'
require 'rgl/dot'
require 'rgl/topsort'

class Array
  def bucket_sort
    extract(buckets, dup)
  end

  def buckets
    buckets_by
  end

  def buckets_by(&block)
    dup.inject(Array.new(0)) do |tmp, n|
      orig_n = n
      n = block.call(n) if block_given?
      k = n / 3
      (tmp[k] ||= []) << orig_n
      tmp
    end
  end

  private

  def extract(buckets, ary)
    idx = 0
    buckets.each do |b_ary|
      next if b_ary.nil?
      b_ary.sort
      b_ary.each_with_index do |el, i|
        ary[idx] = el
        idx += 1
      end
    end
    ary
  end
end

# This is what gets stored in the dependency graph
# #to_s allows us to use RGL while maintaining some semblance of state (date, url) from the article
GraphedArticle = Struct.new(:name, :date, :url, :graph, :keyword) do
  def to_s
    name
  end

  def full_description(graph,dependents=false)
    ret = "In this graph, #{name}, published on #{date} (#{url}), influences #{graph.out_degree(self)} articles"
    if dependents
      ret << "\nLeads to the following sources: "
      printed = []
      adjacent = graph.adjacent_vertices(self)

      while adjacent.count > 0 do
        v = adjacent.shift
        next if printed.include?(v) || v == nil
        ret << v.name
        ret << "\n"
        printed << v
        adjacent += graph.adjacent_vertices(v)
      end
    end
    ret
  end

  def influence(graph=self.graph)
    graph.out_degree(self)
  end
end

class Parser
  attr_accessor :query, :alchemy_api_keys
  attr_accessor :articles, :grouped_articles, :dependency_graphs

  NUMBER_OF_ARTICLES_TO_TAG = 0 # Set to 0 to tag all the thing
  NUMBER_OF_RELEVANT_KEYWORDS_TO_CONSIDER = 1
  NUMBER_OF_KEYWORDS_TO_CONSIDER = 5

  def initialize(query, alchemy_api_keys)
    @query = query
    @alchemy_api_keys = Array(alchemy_api_keys)
  end

  def run!(with_grouped_data_fixture = false)
    unless with_grouped_data_fixture
      parse_json
      group_articles_by_keywords!
      dump_grouped_json
    else
      load_grouped_json
    end
    #find_first_article_for_each_source!
    construct_dependency_graphs!
    #write_dependency_graphs!
    find_epicenters_and_most_influential
  end

  private

  def dump_grouped_json
    File.open("./#{query.gsub(' ', '_')}_grouped.json", 'w') { |f| f.write(@grouped_articles.to_json) }
  end

  def load_grouped_json
    @grouped_articles = JSON.load(File.new("#{@query.gsub(' ', '_')}_grouped.json"))
  end

  def write_dependency_graphs!
    @dependency_graphs.each do |kw, graph|
      File.open("./graph_#{kw.gsub(' ', '_')}.dot", 'w') { |f| f.write(graph.to_dot_graph.to_s) }
    end
  end

  def find_epicenters_and_most_influential
    # TODO implement
    # Find the most important node in each graph
    best_vertices = []
    @dependency_graphs.each do |kw, graph|
      next if graph.vertices.count <= 10
      important_bucket = graph.vertices.buckets_by { |v| v.influence(graph) }.last
      best = important_bucket.sort_by(&:date).first
      # Group the vertices by order of magnitude; pick the most important order of magnitude
      # Pick the first one reported in that order of magnitude
      if best.influence(graph) > 10
        puts "Keyword: #{kw}:"
        puts best.full_description(graph, true)
      end
    end
  end

  def parse_json
    @articles = JSON.load(File.new("#{@query.gsub(' ', '_')}.json"))
  end

  def group_articles_by_keywords!
    group_relevances = Hash.new { |hash, key| hash[key] = [] } # HACK that allows arbitrary initialization to work. Initialize all new keys to empty array
    @grouped_articles = Hash.new { |hash, key| hash[key] = [] }
    considered_articles = (NUMBER_OF_ARTICLES_TO_TAG == 0 ? @articles : @articles.first(NUMBER_OF_ARTICLES_TO_TAG))

    considered_articles.each do |article|
      # Take the top 5 keywords from the article, sorted by relevance
      tags = alchemy_api.query(article['url'])['keywords']

      tags = tags.sort do |a,b|
        a['relevance'].to_f <=> b['relevance'].to_f
      end.last(NUMBER_OF_RELEVANT_KEYWORDS_TO_CONSIDER)

      # Put the article into a group for each of these categories
      tags.each do |tag|
        @grouped_articles[tag['text'].downcase] << article
        # Construct a parallel data set to enable us to sort groups by total relevance...
        group_relevances[tag['text'].downcase] << tag['relevance'].to_f
      end
    end

    group_relevances.each do |kw, vals|
      avg = vals.inject(:+)/vals.count
      group_relevances[kw] = avg
    end

    # Make sure that we pick the keywords that have the most relevance and sufficient articles
    grouped_articles = Hash[@grouped_articles.sort_by { |k, v| v.count }.select do |k, v|
      v.count > 1
    end.reverse[0..NUMBER_OF_KEYWORDS_TO_CONSIDER].sort_by { |k, v| group_relevances[k].to_f }[0..NUMBER_OF_KEYWORDS_TO_CONSIDER]]
  end

  def find_first_article_for_each_source!
    @grouped_articles = @grouped_articles.each do |kw, articles|
      grouped_articles = articles.group_by { |article| article['source'] }
      grouped_articles.each do |source, source_articles|
        grouped_articles[source] = source_articles.min { |article| DateTime.parse(article['date']) }
      end.values
    end
  end

  def construct_dependency_graphs!
    # TODO should this be solely based on date?
    # TODO verify that this works as expected...
    @dependency_graphs = @grouped_articles
    @dependency_graphs.each do |keyword, articles|
      map = build_adjacency_graph
      found_a_vertex = false
      articles.each do |article|
        vertices = map.vertices.dup
        vertices.each do |existing_vertex|
          next if existing_vertex.to_s == article['source']
          found_a_vertex = true
          if is_later_than(existing_vertex, article)
            map.add_edge(existing_vertex, encode_article_to_vertex(article))
          else
            map.add_edge(encode_article_to_vertex(article), existing_vertex)
          end
        end
        map.add_vertex(encode_article_to_vertex(article)) unless found_a_vertex
      end
      @dependency_graphs[keyword] = map
    end
  end

  def build_adjacency_graph
    RGL::DirectedAdjacencyGraph.new
  end

  def is_later_than(existing_vertex, article)
    extract_date(existing_vertex) < extract_date(article)
  end

  def extract_date(article)
    if article.is_a?(Hash) && article['date'] != nil
      return DateTime.parse(article['date'])
    elsif article.is_a?(GraphedArticle)
      return DateTime.parse(article.date)
    end
  end

  def encode_article_to_vertex(article_obj)
    GraphedArticle.new(article_obj['source'], article_obj['date'], article_obj['url'])
  end

  def alchemy_api
    @alchemy ||= Api::AlchemyManager.new(@alchemy_api_keys)
  end
end

