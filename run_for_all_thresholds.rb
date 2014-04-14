(5..100).step(5) do |threshold|
  float_val = threshold.to_f / 100.0
  `ruby full_run.rb #{float_val} > output/#{threshold}.out`
  result_count = File.open("output/#{threshold}.out").read.split("\n").last.split(" ")[1].to_i
  puts "Got #{result_count} results for threshold of #{threshold}%"
end
