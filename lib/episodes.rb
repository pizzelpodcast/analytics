class Episodes
  include Enumerable

  attr_reader :oldest_date, :most_recent_date

  def initialize
    @episodes ||= {}
    @oldest_date = nil
    @most_recent_date = nil
  end

  def [](name)
    @episodes[name] ||= DownloadsMap.new(self)
  end

  def each(&block)
    @episodes.each(&block)
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
      episodes.observe_date(date)
      @dates[date] = value
    end
  end
end
