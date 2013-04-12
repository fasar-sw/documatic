# -*- encoding: utf-8 -*-
require File.expand_path('../lib/documatic/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Dave Nelson", "Antonio Liccardo", "Zachris Trolin", "Stefano Alloro"]
  gem.email         = ["steve.alloro@gmail.com"]
  gem.description   = %q{Forked from http://github.com/zachris/documatic. This branch simply adds default UTF-8 encoding on most of the source files and a brand new demo invoice document to test the output results. New bundler-friendly gemspecs were added also.}
  gem.summary       = %q{Documatic: ruby reports templating of Open Document Text and Spreadsheet}
  gem.homepage      = "http://github.com/fasar-sw/documatic"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "documatic"
  gem.require_paths = ["lib"]
  gem.version       = Documatic::VERSION

#  gem.platform      = Gem::Platform::RUBY
  gem.autorequire   = "documatic.rb"
  gem.has_rdoc      = false
  gem.extra_rdoc_files = ["README"]
  gem.add_dependency("ruport")
  gem.add_dependency("rubyzip")
end
