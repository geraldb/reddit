require 'hoe'
require './lib/upman/version.rb'

Hoe.spec 'upman' do

  self.version = Upman::VERSION

  self.summary = 'upman - Update Manager in Ruby'
  self.description = summary

  self.urls    = ['https://github.com/webstart/upman']

  self.author  = 'Gerald Bauer'
  self.email   = 'example@googlegroups.com'

  # switch extension to .markdown for gihub formatting
  self.readme_file  = 'README.md'
  self.history_file = 'History.md'

  self.extra_deps = [
    ['logutils', '>= 0.6'],
    ['fetcher', '>= 0.4']
  ]

  self.licenses = ['Public Domain']

  self.spec_extras = {
   :required_ruby_version => '>= 1.9.2'
  }

end