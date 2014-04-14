require 'json'
require 'pry'
require 'rgl/adjacency'
require 'rgl/dot'
require 'rgl/topsort'
require 'parallel'
require 'uhferret'
require_relative './api/pagerank_manager.rb'

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
class Parser
  attr_accessor :query, :alchemy_api_keys
  attr_accessor :articles, :grouped_articles, :dependency_graphs

  NUMBER_OF_ARTICLES_TO_TAG = 0 # Set to 0 to tag all the thing
  NUMBER_OF_RELEVANT_KEYWORDS_TO_CONSIDER = 1
  NUMBER_OF_KEYWORDS_TO_CONSIDER = 5

  DEFAULT_PLAGARISM_SIMILARITY_THRESHOLD = 0.9
  # 3 - 41
  # 4 - 32
  # 5 - 32
  # 6 - 32
  # 7 - 32
  # 8 - 32
  # 9 - 6
  # 10 - 32

  def initialize(query, alchemy_api_keys, plagarism_similarity_threshold = DEFAULT_PLAGARISM_SIMILARITY_THRESHOLD)
    @query = query
    @alchemy_api_keys = Array(alchemy_api_keys)
    @plagarism_similarity_threshold = plagarism_similarity_threshold
  end

  def run!
    parse_json
    clean_tmp_directory!
    perform_plagarism_detection!
  end

  private

  def clean_tmp_directory!
    FileUtils.rm_rf(Dir.glob('./tmp/*'))
  end

  def dump_grouped_json
    File.open("./#{query.gsub(' ', '_')}_grouped.json", 'w') { |f| f.write(@grouped_articles.to_json) }
  end

  def load_grouped_json
    @grouped_articles = JSON.load(File.new("#{@query.gsub(' ', '_')}_grouped.json"))
  end

  def parse_json
    @articles = Article.all.all(keyword: @query)
  end

  def perform_plagarism_detection!
    # Dump contents of articles to tmp files
    # Add tmp files to uhferret
    # Run uhferret
    @ferret = UHFerret::Ferret.new
    @articles.each do |article|
      File.open("./tmp/#{article.filename}.tmp", 'w') { |f| f.write(article.contents) }
      @ferret.add("./tmp/#{article.filename}.tmp")
    end
    @ferret.run

    @dependency_graph = build_adjacency_graph

    @ferret.each_pair do |i,j|
      if @ferret.resemblance(i, j) > @plagarism_similarity_threshold
        # Add to the DAG
        article_1 = get_article_by_filename(@ferret[i].filename)
        article_2 = get_article_by_filename(@ferret[j].filename)
        next if article_1.source == article_2.source # Do not consider self-plagarism

        if is_later_than(article_1, article_2)
          @dependency_graph.add_edge(article_1, article_2)
        else
          @dependency_graph.add_edge(article_2, article_1)
        end
      end
    end
    @dependency_graph.write_to_graphic_file('png')
    root_nodes = []

    begin
      iterator = @dependency_graph.topsort_iterator
      next_is_root = true
      depth = 0
      while root_node = iterator.basic_forward
        if next_is_root
          next if @dependency_graph.out_degree(root_node) == 0
          root_nodes.last[1] = depth if root_nodes.any?
          depth = 0
          puts "Identified root node: #{root_node}: #{root_node.url}"
          root_nodes << [root_node.id, 0]
          next_is_root = false
        else
          depth += 1
          print "|"
          depth.times { print "-" }
          puts "#{root_node} : #{root_node.url}"
        end
        next_is_root = true if (@dependency_graph.out_degree(root_node) || 0) == 0
      end
    rescue Exception => ex ; end
    return root_nodes
  end

  def get_article_by_filename(filename)
    Article.get(filename.gsub(".tmp", "").to_i)
  end

  def build_adjacency_graph
    RGL::DirectedAdjacencyGraph.new
  end

  def is_later_than(existing_vertex, article)
    extract_date(existing_vertex) < extract_date(article)
  rescue
    binding.pry
  end

  def extract_date(article)
    if article.is_a?(Hash) && article['date'] != nil
      return DateTime.parse(article['date'])
    elsif article.is_a?(Article)
      return article.date
    end
  end

  def encode_article_to_vertex(article_obj, keyword)
    a = Article.new
    a.name = article_obj['source']
    a.date = DateTime.parse(article_obj['date'])
    a.url = article_obj['url']
    a.keyword = keyword
    a.save
    a
  end

  def alchemy_api
    @alchemy ||= Api::AlchemyManager.new(@alchemy_api_keys)
  end
end

