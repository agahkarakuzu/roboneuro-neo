source 'https://rubygems.org'

if ENV["CUSTOM_RUBY_VERSION"]
  ruby ENV["CUSTOM_RUBY_VERSION"]
end

gem 'octokit'
gem 'sinatra', '4.1.1'
gem 'sinatra-contrib', '4.1.1'
gem 'openssl'
gem 'puma'
gem 'sidekiq'
gem 'bibtex-ruby'
gem 'faraday'
gem 'faraday-retry'
gem 'serrano'
gem 'rexml'
gem 'github-linguist'
gem 'licensee'
gem 'issue'
gem 'chronic'

group :test do
  gem 'rack-test'
  gem 'rspec'
  gem 'webmock'
  gem 'sqlite3'   # COAR Notify's in-memory database in the test settings
end

eval_gemfile './Gemfile_custom'