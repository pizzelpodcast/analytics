require "yaml"
require "pathname"

module Pizzel
  USER_DIR = Pathname.new(File.expand_path("~/.pizzel")).freeze

  def self.config
    @config ||= YAML.load_file(USER_DIR.join("config")).freeze
  end
end
