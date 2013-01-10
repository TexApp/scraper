# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scraper/version'

Gem::Specification.new do |gem|
  gem.name          = "scraper"
  gem.version       = Scraper::VERSION
  gem.authors       = ["Don Cruse", "Kyle Mitchell"]
  gem.description   = %q{Scrape slip opinions of the Texas Courts of Appeals}
  gem.summary       = <<-EOF
    A compact utility for querying the webpages of the Texas Courts of Appeals,
    detecting slip opinions and downloading relevant PDF files while preserving
    metadata.
  EOF
  gem.homepage      = "https://github.com/texapp/scraper"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
