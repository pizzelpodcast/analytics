# frozen_string_literal: true

require "mechanize"
require "pizzel/episodes"

module Pizzel
  class Podtrac
    LOGIN_URL = "https://publisher.podtrac.com/account/login"

    attr_reader :config

    Config = Struct.new(:username, :password, keyword_init: true) do
      def initialize(*args)
        super
        raise ArgumentError, "missing username" unless username
        raise ArgumentError, "missing password" unless password
      end
    end

    def initialize(config)
      @config = Config.new(config).freeze
    end

    def scrape_episode_daily_data(episodes: nil, since: nil)
      episodes ||= Episodes.new

      since ||= episodes.most_recent_date

      current_page = daily

      loop do
        # Table columns don't contain years, so we need to figure it out through
        # the current page's URL
        #
        # Note that the year for the current page belongs to the left-most
        # column, so if we're on a page that begins at the end of december (e.g.
        # left-most column is Dec 31) some of the columns on the right might
        # actually skip into January of the next year
        year = daily_uri_to_year(current_page.uri)

        table = current_page.css(".report table[width='100%']")

        # Find the dates displayed in the current page, first as just month/day
        # pairs
        #
        # We reverse the order since we're traversing the pages backwards (i.e.
        # most recent to oldest), that way the resulting dates/counts hash will
        # preserve the right order
        raw_dates = table.css("tr.group-row:first th")[2..-1].reverse.map do |th, i|
          th.text.strip.split("/").map(&:to_i)
        end

        # Build actual date objects skipping to next year if needed
        dates = raw_dates.map do |(month, day)|
          Date.new(
            (raw_dates.first.first == 12 && month == 1) ? year + 1 : year,
            month,
            day
          )
        end

        # Check if we've reached the given date lower bound
        break if since && dates.last <= since

        table.css("tr.data-row").each do |tr|
          # See note above about reversing order
          row = tr.css("td, th").reverse.map { |cell| cell.text.strip.gsub(/\r\n|\n/, " ").squeeze(" ") }

          ep = episodes[row.pop]

          row.pop # ignore "all time" metric

          row.each.with_index do |v, i|
            normalized_value = typecast_count(v)
            ep[dates[i]] = normalized_value if normalized_value
          end
        end

        previous_link = current_page.link_with(text: /previous period/)

        # Check if we've reached the bottom
        break if previous_link.uri.path == current_page.uri.path

        with_reporting("Fetching previous reports page") do
          current_page = previous_link.click
        end
      end

      episodes
    end

    def daily
      @daily ||= begin
        dashboard = self.dashboard

        reports = with_reporting("Fetching reports page") do
          dashboard.link_with(text: "Reports").click
        end

        with_reporting("Fetching daily reports") do
          reports.link_with(text: "Daily").click
        end
      end
    end

    def dashboard
      @dashboard ||= begin
        login_page = with_reporting("Fetching login page") { agent.get LOGIN_URL }

        with_reporting("Logging in") do
          login_form = login_page.forms.first
          login_form.Email = config.username
          login_form.ClearPasscode = config.password
          agent.submit(login_form, login_form.buttons.first)
        end
      end
    end

    private

    def agent
      @agent ||= Mechanize.new
    end

    def typecast_count(count)
      return nil if count == "-"
      count.gsub(",", "").to_i
    end

    def daily_uri_to_year(uri)
      segment = uri.path[/[0-9_-]+$/]

      if segment == "_"
        begin
          # Try to get the Podtrac server date
          r = agent.head(uri)
          return DateTime.parse(r.response.fetch("date")).year
        rescue
          # If that fails default to local date
          return Time.now.year 
        end
      end

      segment[/\d{4}/].to_i
    end

    def with_reporting(action)
      print(action + "... ")
      yield.tap { puts "✓" }
    rescue Exception => e
      puts "FAILED"
      raise e
    end
  end
end
