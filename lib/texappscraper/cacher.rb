require 'date'
require 'cloudfiles'
require 'open-uri'
require 'texappscraper/db/models'

module TexAppScraper
  class Cacher
    attr_accessor :cloudfiles # connection
    attr_accessor :container # where to save files
    attr_accessor :log

    def initialize cloudfiles, container, log=nil
      @cloudfiles = cloudfiles
      @container = container
      @log = log || Logger.new("/dev/null")
    end

    def mirror(courts, from, through, again)
      # exclude weekends
      date_range = (from..through).to_a.reject { |d| d.saturday? || d.sunday? }

      # scrape
      courts.each do |court|
        court_number = court[:number]
        @log.info court['name']

        scraper = TexAppScraper::for(court_number)

        date_range.each do |date|
          # already scraped?
          if !again && Log.first(:court => court_number, :date => date)
            @log.info "Skipping #{date}: already scraped"
            next
          end

          cases = {}
          # scrape opinions
          scraper.scrape(date) do |opinion_hash|
            case_hash = opinion_hash[:case]
            docket_number = case_hash[:docket_number]
            @log.info "Scraped opinion for case #{docket_number}"
            case_record = cases[docket_number] || save_case(case_hash)
            save_opinion case_record, opinion_hash
          end

          Log.create :court => court_number, :date => date
        end # date

      end # court
    end

    def save_case case_hash
      record = Case.first :docket_number => case_hash[:docket_number]
      unless record
        @log.info "New case: " + case_hash[:docket_number]
        record = Case.create case_hash
      end
      record
    end

    def save_file docket, md5sum, file
      filename = "#{docket}_#{md5sum}.pdf"
      container = @cloudfiles.container(@container)
      if container.object_exists?(filename)
        @log.warn "File existed: #{filename}"
      else
        object = container.create_object filename
        @log.info "File uploading: #{filename}"
        object.write file
      end
    end

    def save_opinion case_record, opinion_hash
      @log.info "Scraped opinion #{opinion_hash[:url]}"

      # file
      file = open opinion_hash[:url]
      md5sum = Digest::MD5.hexdigest file.path
      opinion_hash.merge!({ :md5sum => md5sum })
      @log.info "Checksum: " + md5sum
      save_file case_record.docket_number, md5sum, file

      # create database record
      record = Opinion.first :md5sum => md5sum
      unless record
        opinion_record = Opinion.new(opinion_hash)
        opinion_record.case = case_record
        opinion_record.save
      end
    end
 end
end
