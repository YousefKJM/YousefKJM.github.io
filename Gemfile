source "https://rubygems.org"

gem "jekyll", "~> 4.2"

group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.15"
  gem "jekyll-sitemap", "~> 1.4"
end

# Ruby 3+ dropped webrick from the standard library; `jekyll serve` needs it.
gem "webrick", "~> 1.8"

platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", "~> 1.2"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]
