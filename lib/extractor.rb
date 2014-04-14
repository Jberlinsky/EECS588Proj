class Extractor
  attr_accessor :query
  attr_accessor :grouped_articles

  def initialize(query)
    @query = query
  end

  def run!
    load_grouped_json
    silence_warnings do
      extract
    end
  end

  def load_grouped_json
    @grouped_articles = JSON.load(File.new("#{@query.gsub(' ', '_')}_grouped.json"))
  end

  def extract
    best_vertices = []
    @grouped_articles.each do |kw, _|
      i = 0
      query = {
        function_score: {
          query: {
            match: {
              keyword: kw
            }
          },
          functions: [{
            field_value_factor: {
              field: :is_first
            }
          }],
          score_mode: :multiply
          #constant_score: {
          #  filter: {
          #    numeric_range: {
          #      influenced_nodes_within_keyword: {
          #        gte: 5
          #      }
          #    }
          #  }
          #}
        }
      }

      add_to_set = 1
      Article.query(query).from(0).size(10000).find_each do |article, hit|
        unless best_vertices.map(&:name).include?(article.name)
          best_vertices << article if add_to_set > 0
          add_to_set -= 1
        end
        break unless add_to_set > 0
      end
    end

    best_vertices.each do |article|
      #puts "Keyword: #{article.keyword}"
      #puts article.full_description
    end

    most_idx = nil
    tie = false
    tied_indices = []

    groups = best_vertices.inject({}) do |hsh, article|
      hsh[article.name] = [] if hsh[article.name].nil?
      hsh[article.name] << article

      if hsh[most_idx].try(:size) == hsh[article.name].size
        tie = true
        tied_indices << article.name
      elsif hsh[most_idx].nil? || hsh[article.name].size > hsh[most_idx].size
        most_idx = article.name
        tie = false
        tied_indices = [article.name]
      end
      hsh
    end

    puts "======== RESULTS FOR '#{@query}' ====="
    if tie
      winning_sources = tied_indices
      puts "The following sources had #{groups[winning_sources.first].count} most influential articles:"
      winning_sources.each { |s| puts s }
      return winning_sources
    else
      winning_source = most_idx
      puts "#{winning_source} had #{groups[winning_source].count} most influential articles."
      return Array(winning_sources)
    end
  end
end
