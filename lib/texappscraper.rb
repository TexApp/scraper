require "texappscraper/version"
require "texappscraper/old_system_scraper"
require "texappscraper/courts"
require "texappscraper/cacher"

module TexAppScraper
  def self.for court_number, delay=nil
    court = COURTS[court_number]
    TexAppScraper.const_get(court['scraper']).new court_number, delay
  end
end
