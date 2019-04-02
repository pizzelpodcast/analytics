require "mechanize"

class Podtrac
  LOGIN_URL = "https://publisher.podtrac.com/account/login".freeze

  attr_reader :config

  def initialize(config)
    @config = config
  end

  def scrape_episode_daily_data
    current_page = daily

    episodes = {}

    loop do
      # Table columns don't contain years, so we need to figure it
      # out through the URL
      year = daily_uri_to_year(current_page.uri)

      table = current_page.css(".report table[width='100%']")

      # Find the dates displayed in the current page
      dates = table.css("tr.group-row:first th")[2..-1].map do |th|
        Date.civil(year, *th.text.strip.split("/").map(&:to_i))
      end

      table.css("tr.data-row").each do |tr|
        row = tr.css("td, th").map { |cell| cell.text.strip.gsub(/\r\n|\n/, " ").squeeze(" ") }

        ep = (episodes[row.shift] ||= {})

        row.shift # ignore "all time" metric

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
        login_form.Email = podtrac_config.fetch(:email)
        login_form.ClearPasscode = podtrac_config.fetch(:password)
        agent.submit(login_form, login_form.buttons.first)
      end
    end
  end

  private

  def agent
    @agent ||= Mechanize.new
  end

  def podtrac_config
    config.fetch(:podtrac)
  end

  def typecast_count(count)
    return nil if count == "-"
    count.gsub(",", "").to_i
  end

  def daily_uri_to_year(uri)
    segment = uri.path[/[0-9_-]+$/]
    return Time.now.year if segment == "_"
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
