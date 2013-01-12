require 'mechanize'
require 'date'
require 'texappscraper/court_data'

module TexAppScraper
  class OldSiteScraper

    attr_writer :throttle

    def initialize(throttle = 3)
      # seconds to sleep after queries to avoid choking the server
      @throttle = throttle
      @agent = Mechanize.new
      @agent.user_agent_alias = "Windows IE 9"
      @agent.max_history = 0
    end

    # Main API method
    def scrape(court, since)
      released_since(court, since).map do |case_id|
        scrape_case(court, case_id)
      end
    end

    def scrape_case(court, id)
      data = case_data(court, id)
      sleep @throttle
      data[:opinions] = data[:opinions].map do |opinion|
        event_id = opinion.delete :event_id
        sleep @throttle
        opinion[:url] = pdf_url(court, scrape_opinion_id(court, event_id))
        opinion
      end
      data
    end

    # the URL for a page listing opinions released
    # on <date> from the court number <court>
    def released_opinions_url(court, date)
      court = TexAppScraper::COURTS[court]
      datestring = date.strftime("%Y%m%d")
      "#{court['site']}/opinions/docket.asp?FullDate=#{datestring}"
    end

    def case_url(court, id)
      court = TexAppScraper::COURTS[court]
      "#{court['site']}/opinions/case.asp?FilingID=#{id}"
    end

    def event_url(court, event_id)
      court = TexAppScraper::COURTS[court]
      "#{court['site']}/opinions/event.asp?EventID=#{event_id}"
    end

    def pdf_url(court, opinion_id)
      court = TexAppScraper::COURTS[court]
      "#{court['site']}/opinions/pdfOpinion.asp?OpinionID=#{opinion_id}"
    end

    def released_since(court, since)
      (since..Date.today).map do |date|
        sleep @throttle
        released(court, date)
      end.flatten
    end

    CASE_RE = /^\/opinions\/case.asp/
    ID_RE = /FilingID=(\d+)/
    def released(court, date)
      url = released_opinions_url(court, date)
      @agent.get(url) do |page|
        return page.links_with(:href => CASE_RE).to_a.map do |link|
          ID_RE.match(link.href)[1].to_i
        end
      end
    end

    TYPE_SYMBOLS = {
      'Memorandum opinion issued' => :memorandum,
      'Opinion issued' => :opinion
    }
    EVENTS = './/*[@id="content-middle2"]/table/tr[2]/td/table[2]/tr'

    def case_data(court, id)
      @agent.get(case_url(court, id)) do |page|
        meta = scrape_case_meta(page)
        meta[:opinions] = scrape_opinion_events(page)
        return meta
      end
    end

    META = '//*[@id="content-middle2"]/table/tr[2]/td/table[1]/tr/td/table/tr'
    META_KEYS = {
      'Case Number:' => :number,
      'Date Filed:' => :filed,
      'Case Type:' => :type,
      'Style:' => :style,
      'v.:' => :versus,
      'Original Proceeding:' => :original
    }
    META_FORMAT = {
      :filed => lambda {|x| Date.strptime(x, '%m/%d/%Y')},
      :original => lambda {|x| x == 'Yes'}
    }

    def scrape_case_meta(page)
      page.search(META).to_a.reduce({}) do |mem, tr|
        key = tr.at_css('td.BreadCrumbs').text
        # terminal non-breaking spaces
        value = tr.at_css('td.TextNormal').text.gsub("\u00A0"," ").strip
        meta_key= META_KEYS[key]
        format = META_FORMAT[meta_key]
        mem[meta_key] = format.nil? ? value : format.call(value)
        mem
      end
    end

    def scrape_opinion_events(page)
      page.search(EVENTS).to_a.slice(1..-2).reduce [] do |mem, tr|
        tds = tr.search('.//td')
        type = tds[2].text
        if TYPE_SYMBOLS.keys.include? type
          href = tds[0].at_css('a').attr('href')
          date = Date.strptime(tds[1].text, '%m/%d/%Y')
          description = tds[3].text
          mem << {
            :type => TYPE_SYMBOLS[type],
            :date => date,
            :event_id => /EventID=(\d+)/.match(href)[1].to_i
          }
        end
        mem
      end
    end

    def scrape_opinion_id(court, event_id)
      @agent.get(event_url(court, event_id)) do |page|
        link = page.link_with(:href => /^Opinion.asp/)
        return /OpinionID=(\d+)/.match(link.href)[1].to_i
      end
    end
  end
end
