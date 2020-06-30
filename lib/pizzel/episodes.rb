# frozen_string_literal: true

module Pizzel
  class Episodes
    include Enumerable

    attr_reader :oldest_date, :most_recent_date

    def self.load(hash)
      episodes = new

      hash[:episodes].each do |name, values|
        ep = episodes[name]
        values.each do |date, count|
          ep[date] = count
        end
      end

      episodes
    end

    def initialize
      @episodes ||= {}
      @oldest_date = nil
      @most_recent_date = nil
    end

    def [](name)
      @episodes[name] ||= DownloadsMap.new(self)
    end
    alias episode []

    def each(&block)
      @episodes.each(&block)
    end

    def to_h
      {
        updated_to: @most_recent_date,
        episodes:   @episodes.transform_values(&:to_h)
      }
    end

    def observe_date(date)
      if @oldest_date.nil?
        @oldest_date = date
        @most_recent_date = date
        return
      end

      @oldest_date = date if date < @oldest_date
      @most_recent_date = date if date > @most_recent_date
    end

    class DownloadsMap
      def initialize(episodes)
        @episodes = episodes
        @dates ||= {}
      end

      def []=(date, value)
        raise ArgumentError, "expected a date for the index" unless date.kind_of?(Date)
        @episodes.observe_date(date)
        @dates[date] = value
      end

      def to_h
        @dates.dup
      end
    end
  end
end
