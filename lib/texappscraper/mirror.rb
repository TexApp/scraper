require 'date'
require 'cloudfiles'
require 'open-uri'
require 'texappscraper/db/models'

module TexAppScraper

  # Tex. R. App. Pro. 47.7
  TRAP_DATE = Date.new(2003, 1, 1)

  # seconds to sleep before downloading a PDF
  THROTTLE_DELAY = 2 

  def self.mirror(courts, from, cf, container_name)
    courts.each do |court|
      court_number = court[:number]
      name = court['name']
      $log.info name
      if from
        scrape_from = from
        $log.info "Scraping from: #{scrape_from}"
      else
        if last_logged = Log.last(:court => court_number)
          scrape_from = last_logged.date - 1
          $log.info "Scraping from last date scraped: #{scrape_from}"
        else
          scrape_from = TRAP_DATE
          $log.warn "Scraping from TRAP date: #{scrape_from}"
        end
      end

      scraper = TexAppScraper::for(court_number)
      scraper.throttle = 1
      scraper.scrape(court_number, scrape_from).each do |c|
        c[:court] = court_number
        $log.info "Scraped case #{c[:number]}"
        opinions = c.delete :opinions
        case_record = process_case(c)
        process_opinions(case_record, opinions, cf, container_name)
      end

      Log.create(:court => court_number, :date => Date.today)
    end
  end

  def self.process_case(c)
    style = c[:style]
    style += " v. #{c[:versus]}" if c[:versus]
    # create database record
    case_record = Case.first(:number => c[:number])
    unless case_record
      $log.info "New case: #{c[:number]}"
      case_record = Case.create({
        :number => c[:number],
        :court => c[:court],
        :style => style,
        :filed => c[:filed],
        :type => c[:type]
      })
    end
    case_record
  end

  def self.process_opinions(case_record, opinions, cf, container_name)
    opinions.each do |opinion|
      $log.info "Scraped opinion #{opinion[:foreign_id]}"
      # create database record
      opinion_record = Opinion.first(:url => opinion[:url])
      unless opinion_record
        # filename convention: 03-12-001177-CV_21724.pdf
        filename = "#{case_record.number}_#{opinion[:foreign_id]}.pdf"
        url = opinion[:url]
        opinion_record = Opinion.new({
          :number => case_record.number,
          :type => opinion[:type].to_s,
          :date => opinion[:date],
          :foreign_id => opinion[:foreign_id],
          :filename => filename,
          :url => url
        })
        opinion_record.case = case_record
        opinion_record.save

        # download the PDF file and save it to the cloud
        container = cf.container(container_name)
        if container.object_exists?(filename)
          $log.warn "File existed: #{filename}"
        else
          object = container.create_object filename
          sleep THROTTLE_DELAY
          $log.info "File uploading: #{filename}"
          # use IO to avoid keeping the whole PDF in memory
          object.write open(url)
        end

        $log.info("New opinion: #{opinion[:url]}")
      end
    end
  end

end
