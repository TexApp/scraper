require "texappscraper/version"
require "texappscraper/old_system_scraper"
require "texappscraper/court_data"
require "texappscraper/cli"

module TexAppScraper
  def self.for(court)
    court = COURTS[court]
    TexAppScraper.const_get(court['scraper']).new
  end
end
