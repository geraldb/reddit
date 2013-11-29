# encoding: utf-8

require 'fileutils'

require 'uri'
require 'net/http'
require 'yaml'
require 'pp'
require 'logger'
require 'optparse'


####
# more gems

require 'logutils'
require 'fetcher'



## todo:  copy paket.txt to meta/ folder
## todo:  needs replace or overwrite option? delete folder before copy/unzip? (default for all or make it an option?)


### todo/fix: fetch_file - check for error (404,etc.)
## todo/fix: add optparse for commandline options (debug?, verbose?, dry run?, etc.)
## todo/fix: check content type for zip,exe,dll (needs binary?)



require 'upman/version'  # let version always go first

require 'upman/opts'
require 'upman/pack'
require 'upman/utils'
require 'upman/downloader'
require 'upman/runner'


module Upman

  def self.banner
    "upman/#{VERSION} on Ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
  end

  def self.main( args )
    runner = Runner.new
    runner.run( args )
  end

end  # module Upman


puts Upman.banner    # say hello
