# TODO:
#
# - Multiple writable targets (Google Spreadsheet, YAML, JSON?)
# - Use previous data to prevent downloading more pages than needed

require "rubygems"
require "bundler/setup"
require "pry"
require "yaml"
require "fileutils"

require_relative "lib/podtrac"

CONFIG = YAML.load_file(File.join(__dir__, "config.yml")).freeze

podtrac = Podtrac.new(CONFIG)

episodes = podtrac.scrape_episode_daily_data

FileUtils.mkdir_p(File.join(__dir__, "data"))

File.open(File.join(__dir__, "data/episodes.yml"), "w") do |f|
  YAML.dump(episodes, f)
end

puts "✓"
