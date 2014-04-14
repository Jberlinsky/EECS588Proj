require_relative './lib/runner.rb'
require_relative './lib/parser.rb'
require_relative './lib/extractor.rb'
require_relative './lib/article_content_downloader.rb'
require_relative './lib/models/models.rb'
require_relative './lib/article_ranker.rb'

#require 'facets'

#Article.destroy_all

ApiKey.create(
  api_key: '8C+6GKN/UHrCiYlVhZ12J2wpTKhpyQZ3VneTZHp2+Qg',
  uses: 5_000,
  provider: 'Bing'
)

bing_api_keys = ApiKey.all.all(provider: 'Bing')
raise "No API keys for Bing provided" unless bing_api_keys.any?

plagarism_similarity_threshold = ARGV[0].to_f

QUERIES = [
  'Boston Marathon Bombing',
  'Enron',
  'MH370',
  'Sandy Hook Elementary',
  'Heartbleed',
  'Crimea',
  'Toyota Recall',
  'Rob Ford',
  'Ford Recall',
  'Egypt President Morsi',
  'Silk Road Dread Pirate',
  'PRISM',
  'Snowden',
  'Target Card HVAC',
  'Michael Vick Puppy',
  'Felix Baumgardner Jump',
  'Balloon boy',
  'SpaceX ISS',
  'Air France 447',
  'Sochi Wolf',
  'Affordable Care Act',
  'AptiQuant Internet Explorer IQ',
  'Will Smith Dead',
  'Betty White Dead',
  'KFC Mutant Chicken'
]

#Article.all.map(&:destroy)
QUERIES.each do |query|
  if Article.for_query(query).count > Article::QUORUM
    puts "We have established a quorum, skipping..."
  else
    Runner.new(query, bing_api_keys).run!
  end
end

Article.destroy_without_quorum

puts "We now have #{Article.count} articles"

QUERIES.each do |query|
  puts "Downloading content for articles in #{query}..."
  #ArticleContentDownloader.new(query).run!
end

puts "Getting Alexa rankings..."
Article.without_alexa_ranking.each do |article|
  ArticleRanker.perform(article.id)
end

root_nodes = []
QUERIES.each do |query|
  puts "Running parser for #{query}..."
  root_nodes << Parser.new(query, [], plagarism_similarity_threshold).run!
end

root_sources = []
root_nodes.flatten.each_slice(2) do |slice|
  root_sources << slice
end

puts "========================================="
puts "Got #{root_sources.flatten.compact.count} root sources for plagarism consideration factor #{plagarism_similarity_threshold}"

# Consider the top (ROOT_SOURCE_COUNT / 10).to_i sources from each analysis type for joining
consideration_count = (root_sources.flatten.compact.count * 0.2).to_i

puts "========================================="
puts "Identifying most frequent root sources..."
puts "These would be great targets to compromise"
puts "========================================="

frequent_root_nodes = root_sources.map(&:first).map { |id| Article.get(id) }.map(&:source)
histogram = frequent_root_nodes.inject(Hash.new(0)) { |hash, x| hash[x] += 1; hash }
map = []
histogram.each do |source, frequency|
  map << [source, frequency]
end
map.sort_by { |r| r.last }.last(consideration_count).each do |r|
  puts "#{r.first} has #{r.last} root nodes of plagarism."
end
most_frequent_sources = map.select.sort_by { |r| r.last }.last(consideration_count).map(&:first)

puts "========================================="
puts "Identifying most influential root sources by number of articles"
puts "These would also be great sources to compromise"
puts "========================================="

influential_root_nodes = root_sources.map(&:first).map { |id| Article.get(id) }
root_sources.map(&:last).each_with_index do |depth, index|
  influential_root_nodes[index].depth = depth
end

most_influential_sources = influential_root_nodes.sort_by(&:depth).last(consideration_count)
most_influential_sources.select { |s| s.depth > 0 }.last(consideration_count).each do |source|
  puts "#{source.source} influences #{source.depth} articles"
end

puts "========================================="
puts "Joining the two analyses above"
best_sources = most_frequent_sources & most_influential_sources.map(&:source)
puts "========================================="

puts best_sources.join(",\n")

puts "========================================="
puts "Got #{best_sources.count} targets!"
