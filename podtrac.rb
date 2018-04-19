require "rubygems"
require "bundler/setup"
require "mechanize"
require "pry"
require "yaml"

def podtrac_count_to_int(count)
  return nil if count == "-"
  count.gsub(",", "").to_i
end

def podtrac_daily_uri_to_year(uri)
  segment = uri.path[/[0-9_-]+$/]
  return Time.now.year if segment == "_"
  segment[/\d{4}/].to_i
end

CONFIG = YAML.load_file("config.yml").freeze

agent = Mechanize.new

print "Fetching login page... "

agent.get("https://publisher.podtrac.com/account/login")

puts "✓"

print "Logging in... "

login_form = agent.page.forms.first
login_form.Email = CONFIG.fetch(:podtrac).fetch(:email)
login_form.ClearPasscode = CONFIG.fetch(:podtrac).fetch(:password)
agent.submit(login_form, login_form.buttons.first)

puts "✓"

print "Fetching reports page... "

agent.page.link_with(text: "Reports").click

puts "✓"

print "Fetching daily reports... "

daily = agent.page.link_with(text: "Daily").click

puts "✓"

episodes = {}

loop do
  # Table columns don't contain years, so we need to figure it
  # out through the URL
  year = podtrac_daily_uri_to_year(daily.uri)

  table = daily.css(".report table[width='100%']")

  # Find the dates displayed in the current page
  dates = table.css("tr.group-row:first th")[2..-1].map do |th|
    Date.civil(year, *th.text.strip.split("/").map(&:to_i))
  end

  table.css("tr.data-row").each do |tr|
    row = tr.css("td, th").map { |cell| cell.text.strip.gsub(/\r\n|\n/, " ").squeeze(" ") }

    ep = (episodes[row.shift] ||= {})

    row.shift # ignore "all time" metric

    row.each.with_index do |v, i|
      ep[dates[i]] = podtrac_count_to_int(v)
    end
  end

  previous_link = daily.link_with(text: /previous period/)

  # Check if we've reached the bottom
  break if previous_link.uri.path == daily.uri.path

  print "Fetching previous reports page... "

  daily = previous_link.click

  puts "✓"
end

p episodes

binding.pry
