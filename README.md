# Running #

1. `bundle install`
2. `ruby full_run.rb`

Without modification, full_run.rb will:

1. Pull down as many Bing search results as it can
2. Store the raw search data in a JSON file
3. Parse the JSON file by running it through Alchemy API and categorizing articles by keywords
4. Save the categorized data in another JSON file
5. Construct a dependency graph for each keyword set (TODO: make sure this is doing something useful)
6. TODO: Do something useful to the graphs

full_run.rb can be optimized to avoid hitting API limitations, etc.:

- Comment out the line starting with 'Runner.new' to use the raw search data from the JSON file in (2)
- Add API keys to the bing_api_keys and alchemy_api_keys arrays. The API client will automatically rotate through them. If a key runs out of accesses, remove and replace it in the file. Try to keep the second argument (estimated number of uses remaining) up to date.
- Add an argument to the Parser#run! statement (i.e `Parser.new(QUERY, ...)).run!(true)`) to skip (3), instead loading the saved data from (4)

# Expected Runtime #

A full run with no optimizations will take approximately __ (as of this commit)
