
module Upman


class PackManifest

  include LogUtils::Logging

  ## todo: split in headers and body hash !!!!!
  #
  #  for now just one hash
  #
  
  # todo: rename to Manifest(File) or similar  ??
  #  - make it "generic" e.g. use manman manifest

  def self.load_file( path )
    self.load( File.read( path ) )
  end

  def self.load( text )
    PackManifest.new( text ).parse
  end

  def initialize( text )
    @text = text
    @text = @text.gsub( /\t/ ) do |_|
      ## replace tabs w/ spaces and issue warning
      logger.info( "*** warn: tabs in manifest (yaml format does NOT allow tabs; sorry); please fix!!! e.g. replace w/ spaces" )
      ' '
    end
  end

  def parse
    ## returns a hash (key/value pairs) for now
    YAML.load( @text )
  end

end  # PackFile



class PackUpdateCursor

  include LogUtils::Logging


  def initialize( paket_alt_hash, paket_neu_hash, extra_headers=[] )
    @paket_alt_hash = paket_alt_hash
    @paket_neu_hash = paket_neu_hash
    @headers = [ 'VERSION', 'UMGEBUNG' ] + extra_headers
  end


  def up_to_date?
    # check if installation is up-to-date
    #  all checksums/md5 must match; no new zips/files etc.

    # chech #1
    #  VERSION must match
    
    version_alt = @paket_alt_hash[ 'VERSION' ] || 'latest'  # todo: use latest ?? or just use no folder ??? 
    version_neu = @paket_neu_hash[ 'VERSION' ] || 'latest'

    unless version_alt == version_neu
      logger.info( "up-to-date check failed - version mismatch #{version_alt} <=> #{version_neu}" )
      return false
    end

    # check #2
    #   entries md5/checksum must match
    #
    #  note: will ignore deleted zips for now (delete zips will not invalidate up-to-date status; fix later)

    new_entries = 0
    
    each do |key, values_alt, values_neu|
      new_entries += 1
    end
    
    if new_entries == 0
      logger.info( "up-to-date check OK" )
      return true
    else
      logger.info( "up-to-date check failed - found #{new_entries} new entries" )
      return false
    end
  end



  def each
    # headers = [ 'VERSION', 'UMGEBUNG' ] + opts.headers

    # get unique key from old and new

    keys = @paket_alt_hash.keys + @paket_neu_hash.keys
    keys = keys.uniq

    keys.each do | key |

      ## todo/future:
      #    make headers all upercase by convention??? why? why not??
      
      # skip these keys (e.g. VERSION, UMGEBUNG, etc.
      
      ### todo:
      ## in the future - use name convention for headers?? makes it generic
      ##  - eg. now all non-headers are zip packages e.g ending w/ .zip
      ##  and all headers are all upcase w/o file extension e.g. VERSION
      
      next   if @headers.include?( key )
      
      lines_alt = @paket_alt_hash[ key ]
      lines_neu = @paket_neu_hash[ key ]
      
      if lines_neu.nil?
        logger.info( "*** skip old manifest entry #{key}; no longer available in new manifest" );
        next
      end
    
      if lines_alt.nil?
        # new manifest entry
        lines_alt = 'md5nil'
      end

      values_alt = lines_alt.strip.split( ',' )
      values_neu = lines_neu.strip.split( ',' )
      
      value_alt = values_alt[ 0 ]  # assume first entry is checksum (md5 hash)
      value_neu = values_neu[ 0 ]

      # nur neue Pakete holen
      if value_alt != value_neu
        logger.debug "#{key} => #{value_neu} != #{value_alt}"
        yield key, values_alt, values_neu
      end
    end
  end
end # class PackUpdateCursor

end # module Upman
