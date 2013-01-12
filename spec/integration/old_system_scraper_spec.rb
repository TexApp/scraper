require 'spec_helper'
require 'fakeweb'
require 'date'
require 'texappscraper/old_system_scraper'

def live_and_cached(should, url, fixture, &block)
  it should, :live do
    block.call subject
  end

  it should, :cached do
    FakeWeb.register_uri :get, url,
      :response => File.read("spec/fixtures/" + fixture)
    block.call subject
  end
end

describe TexAppScraper::OldSiteScraper do

  # delay live tests to avoid stressing the server
  before :each, :live => true do
    sleep 3
  end

  COURT = 3
  DATE = Date.new 2013, 1, 9
  OPINIONS = [15688, 17116, 17566, 17511]
  RELEASED_FIXTURE = "3rd-released-20130109"
  RELEASED_URL = "http://www.3rdcoa.courts.state.tx.us/opinions/docket.asp?FullDate=20130109"
  live_and_cached 'scrapes released opinions', RELEASED_URL, RELEASED_FIXTURE do |subject|
    subject.released(COURT, DATE).should =~ OPINIONS
  end

  it "scrapes cases and opinions", :live, :api do
    subject.scrape_case(3, 15688).should == {
      :number => "03-10-00663-CV",
      :filed => Date.new(2010, 9, 30),
      :type => "Real Property",
      :style => "Alvin W. Byrd, Jr.",
      :versus => "Nicolas & Morris, a Texas General Partnership",
      :original => false,
      :opinions => [
        {
          :type => :memorandum,
          :date => Date.new(2013, 1, 9),
          :url => "http://www.3rdcoa.courts.state.tx.us/opinions/pdfOpinion.asp?OpinionID=21719"
        }
      ]
    }
  end

  CASE_FIXTURE = '03-12-00177-CV'
  CASE_URL = 'http://www.3rdcoa.courts.state.tx.us/opinions/case.asp?FilingID=16995'
  CASE_ID = 16995
  CASE_DATA = {
    :number => '03-12-00177-CV',
    :type => 'Divorce',
    :filed => Date.new(2012, 3, 9),
    :type => 'Divorce',
    :style => 'Danette Marilou Pappas',
    :versus => 'William Michael Pappas',
    :original => false,
    :opinions => [
      {
        :type => :memorandum,
        :date => Date.new(2013, 1, 10),
        :event_id => 470586
      }
    ]
  }
  live_and_cached "scrapes case pages", CASE_URL, CASE_FIXTURE do |subject|
    subject.case_data(COURT, CASE_ID).should == CASE_DATA
  end

  EVENT_ID = 470586
  OPINION_ID = 21724
  EVENT_URL = 'http://www.3rdcoa.courts.state.tx.us/opinions/event.asp?EventID=470586'
  EVENT_FIXTURE = '3-event-470586'
  live_and_cached "scrapes opinion IDs", EVENT_URL, EVENT_FIXTURE do |subject|
    subject.scrape_opinion_id(COURT, EVENT_ID).should == OPINION_ID
  end
end
