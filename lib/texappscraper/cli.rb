require 'bundler/setup'
require 'yaml'
require 'texappscraper'
require 'thor'
require 'logger'
require 'dm-core'

module TexAppScraper
  CONFIG = File.join(File.dirname(__FILE__), '..', '..', 'config', 'credentials.yml')
  CREDENTIALS = YAML.load_file(CONFIG)

  class CLI < Thor
    option :log, :aliases => '-l',
      :default => '/dev/stdout',
      :banner => "where to print log messages"
    option :verbose, :aliases => '-v',
      :type => :boolean,
      :default => false,
      :banner => "verbose log output"
    option :again, :aliases => '-a',
      :type => :boolean,
      :default => false,
      :banner => "scrape previously scraped days again"
    option :from, :aliases => '-f',
      :type => :string,
      :default => Date.new(2003, 1, 1),
      :banner => "scrape opinions from YYYY-MM-DD"
    option :through, :aliases => '-t',
      :type => :string,
      :default => Date.today,
      :banner => "scrape opinions through YYYY-MM-DD"
    option :courts, :aliases => '-c',
      :multiple => :string,
      :default => TexAppScraper::COURTS.keys.join(','),
      :banner => 'courts to scrape'
    desc "scrape", (
      <<-EOS
        Scrape data and opinions from the courts of the Texas Courts of Appeals,
        saving the results in a local database and cloud storage
      EOS
    ).gsub(/ +/, ' ')
    def scrape
      # database connection
      DataMapper.setup(:default, CREDENTIALS['database'])

      # set up logging
      $log = Logger.new(options.log)
      $log.level = options.verbose ? Logger::INFO : Logger::WARN

      courts = options.courts.split(',').map(&:to_i).map do |i|
        TexAppScraper::COURTS[i].merge({:number => i})
      end

      # CloudFiles connection
      $log.info "CloudFiles user: #{CREDENTIALS['cloudfiles']['username']}"
      cloudfiles = CloudFiles::Connection.new(
        CREDENTIALS['cloudfiles'].reduce({}) do |mem, pair|
          mem.merge({pair[0].to_sym => pair[1]})
        end
      )
      
      container_name = CREDENTIALS['container']
      $log.info "CloudFiles container: #{container_name}"
      cloudfiles.container container_name

      from = Date.parse options.from
      through = Date.parse options.through

      $log.info "Mirroring cases"
      cacher = Cacher.new cloudfiles, container_name, $log
      cacher.mirror courts, from, through, options.again
    end

    option :migrate, :aliases => '-m', :type => :boolean, :default => false,
      :desc => 'auto_migrate!, wiping out existing data'
    desc "migrate", (
      <<-EOS
        Upgrade the database to reflect changes to the DataMapper models
      EOS
    ).gsub(/ +/, ' ')
    def migrate
      DataMapper.setup(:default, CREDENTIALS['database'])
      if options.migrate
        DataMapper.auto_migrate!
      else
        DataMapper.auto_upgrade!
      end
    end
  end

end
