require 'yaml'

module TexAppScraper
  DATA_DIR = Gem::datadir('texappscraper')
  COURTS = YAML::load_file(File.join(DATA_DIR, 'courts.yml'))
end
