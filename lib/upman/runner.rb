# encoding: utf-8

#
# require 'java'     # Let's use some Java (needed for unzip)



module Upman

class Runner

  include LogUtils::Logging
  
  include Utils  # e.g. fetch_file, unzip_file etc  - use FileUtils instead  - why ??? why not???

  def initialize
  
    @opts = Opts.new
  end

  attr :paket_alt_hash    # note: attr only creates readers (getters) 
  attr :paket_neu_hash
  attr :opts


  def run( args )

    puts "upman version #{VERSION} on Ruby #{RUBY_VERSION}-#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"

    optparse = OptionParser.new do |cmd|
    
      cmd.banner = "Usage: upman [options]"
    
      cmd.on( '-f', '--fetch URI', 'Download Server Source' ) do |uri|
        opts.fetch_base = uri
      end

      cmd.on( '-n', '--name NAME', "Manifest Name (default: #{opts.manifest_name})" ) do |name|
        opts.manifest_name = name
      end
    
      # todo: find different letter for debug trace switch (use v for version?)
      cmd.on( "-v", "--verbose", "Show debug trace" ) do
        ## fix: use LogUtils
        ## logger.level = Logger::DEBUG
      end
 
      cmd.on_tail( "-h", "--help", "Show this message" ) do
         puts
         puts cmd.help
         exit
      end
    end

    optparse.parse!( args )
  
    
    # lets go - do it.
      
    status = step0_config                   # get and check packages, only continue if status is OK, that is, 0
    status = step1_download if status == 0  
 #            step2_copy     if status == 0  
  end


  def step0_config
    logger.info "===== step 0: config"
  
    paket_alt = "#{opts.meta_dir}/#{opts.manifest_name}.txt"
    ts = Time.now
    # note: -- save to tmp (only change over to paket/paket.txt) if everything downloaded
    @paket_tmp = paket_tmp = "#{opts.download_dir}/tmp/__#{ts.strftime('%Y-%m-%d_%H.%M-%S')}__#{opts.manifest_name}.txt.tmp"

    ## make sure downloads/tmp folder exists
    FileUtils.makedirs( "#{opts.download_dir}/tmp" ) unless File.directory?( "#{opts.download_dir}/tmp" )


    if File.exists?( paket_alt ) == false
      logger.error "Unvollständige Installation (Manifest Datei '#{opts.manifest_name}.txt' nicht gefunden in META Ordner '#{opts.meta_dir}')"
      return 1 # Fehler
    end

    # todo/fix: -- delete paket_neu if exists?  - no! never delete; move to trash folder
  
    paket_fetch_uri = "#{opts.fetch_base}/#{opts.manifest_name}.txt"

    ok = fetch_file( paket_fetch_uri, paket_tmp )

    return 1  unless ok   # error fetching paket.txt


    if File.exists?( paket_tmp ) == false
      logger.error "Unvollständiges Paket (Manifest Datei 'paket.txt' nicht gefunden in DOWNLOAD Ordner)"
      return 1 # Fehler
    end   


    ### todo: use a yaml reader utility method
    ##  move to utils ??? for reuse

    yaml_alt = File.read( paket_alt )
    yaml_alt = yaml_alt.gsub( /\t/ ) do |_|
      ## replace tabs w/ spaces and issue warning
      logger.info( "*** warn: tabs in manifest (yaml) - #{paket_alt}; please fix!!! e.g. replace w/ spaces" )
      ' '
    end

    yaml_tmp = File.read( paket_tmp )
    yaml_tmp = yaml_tmp.gsub( /\t/ ) do |_|
      ## replace tabs w/ spaces and issue warning
      logger.info( "*** warn: tabs in manifest (yaml) - #{paket_tmp}" )
      ' '
    end

    @paket_alt_hash = YAML.load( yaml_alt )
    @paket_neu_hash = YAML.load( yaml_tmp )


    ## todo/fix: add debug option to toggle dumping of package hash

    puts "paket_neu_hash:"
    pp paket_neu_hash
  
    puts "paket_alt_hash:"
    pp paket_alt_hash
      
  
    # Download Paketversion muss >= Installation sein.

    version_alt = paket_alt_hash[ 'VERSION' ]
    version_neu = paket_neu_hash[ 'VERSION' ]
  
    logger.info "VERSION:  #{version_alt} => #{version_neu}"

    if version_alt && version_neu
      # convert version to number:
      #  version info format:  (2013.06r01) - <YYYY>.<MM>r<RELEASE>
      #     2013.06r01 becomes 20130601  for easy comparison using ints
      #     2013.05r02 becomes 20130502  etc.

      version_alt_num  =  version_alt.to_s.gsub( /[a-z\-._]/i, '' ).to_i
      version_neu_num  =  version_neu.to_s.gsub( /[a-z\-._]/i, '' ).to_i

      logger.info "VERSION NUM: #{version_alt_num} => #{version_neu_num}"

      if version_alt_num > version_neu_num 
        logger.error "Downgrade nicht zulässig von Version #{version_alt} nach #{version_neu}."
        return 1 # Fehler
      end
    end
    

    # Wechsel von Produktion auf Test unterbinden
  
    umgebung_alt = paket_alt_hash[ 'UMGEBUNG' ] 
    umgebung_neu = paket_neu_hash[ 'UMGEBUNG' ]

    logger.info "UMGEBUNG: #{umgebung_alt} => #{umgebung_neu}"
  
    if umgebung_alt && umgebung_neu
       if umgebung_alt == 'PRODUKTION' && umgebung_neu != 'PRODUKTION'
         logger.error "Testpakete können nicht auf eine Produktionsversion installiert werden."
         return 1 # Fehler
       end
    end

    return 0 # OK
  end


  ###
  ###
  ## todo/fix:
  ##  -- make it into a (reusable) class - PackUpdateCursor ???
  ##  e.g. pass in hash_new, hash_old , plus optional headers
  
  def paket_on_update
    headers = [ 'VERSION', 'UMGEBUNG' ] + opts.headers

    # get unique key from old and new

    keys = paket_alt_hash.keys + paket_neu_hash.keys
    keys = keys.uniq


    keys.each do | key |
      
      # skip these keys (e.g. VERSION, UMGEBUNG, etc.
      next   if headers.include?( key )
      
      lines_alt = paket_alt_hash[ key ]
      lines_neu = paket_neu_hash[ key ]
      
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


  def step1_download
    logger.info "==== step 1: download"

    dl = Downloader.new( opts.fetch_base, opts.download_dir )

    paket_on_update do |key, values_alt, values_neu|
      entry_key = key
      entry_md5 = values_neu[0]
      
      ok = dl.process( entry_key, entry_md5 )
      
      return 1  unless ok   # on error return; break
    end

    return 0 # OK  
  end # method step1_download


  def step2_copy   ### step2_unpack  or use step2_prepare ???
    logger.info "==== step 2: copy"


    ## todo: use latest ?? or just use no folder ??? 
    version_neu = paket_neu_hash[ 'VERSION' ] || 'latest'


    # -- make sure folders updates n patches exist
    FileUtils.makedirs( "#{opts.download_dir}/#{version_neu}/updates" ) unless File.directory?( "#{opts.download_dir}/#{version_neu}/updates" )
    FileUtils.makedirs( "#{opts.download_dir}/#{version_neu}/patches" ) unless File.directory?( "#{opts.download_dir}/#{version_neu}/patches" )
    FileUtils.makedirs( "#{opts.download_dir}/#{version_neu}/paket" ) unless File.directory?( "#{opts.download_dir}/#{version_neu}/paket" )

    paket_on_update do |key, values_alt, values_neu|
      if values_neu.length < 2   # we need at least to parameters for copy operation (2nd para has copy instructions)
        logger.error 'missing operation spec; expected min two values/args'
        next
      end

      copy_values = values_neu[1].strip.split( ' ' )
      if copy_values.length == 2
        copy_op     = copy_values[0].strip
        copy_dest   = copy_values[1].strip

        ## todo/fix - check: if paket/key exists? if yes, assume already unzipped
        ##   - moved zip is confirmation
        ##   - lets us resume unpack and try again and again etc.

        if copy_op.downcase == 'clean'
          unzip_file( "#{opts.download_dir}/tmp/#{key}", "#{opts.download_dir}/#{version_neu}/updates/#{copy_dest}" )
          
          ## on success - move zip from /tmp to /paket
          FileUtils.mv( "#{opts.download_dir}/tmp/#{key}", "#{opts.download_dir}/#{version_neu}/paket/#{key}", force: true, verbose: true )

        elsif copy_op.downcase == 'update'
          unzip_file( "#{opts.download_dir}/tmp/#{key}", "#{opts.download_dir}/#{version_neu}/patches/#{copy_dest}" )

          ## on success - move zip from /tmp to /paket
          FileUtils.mv( "#{opts.download_dir}/tmp/#{key}", "#{opts.download_dir}/#{version_neu}/paket/#{key}", force: true, verbose: true )

        else
          logger.error 'Unknown copy operation in instruction in paket.txt. Expected clean|update'
        end
      else
        logger.error 'Invalid copy instruction in paket.txt. Expected zip|file ziel'
      end      
    end
    
    ## on success - move paket.txt as last step
    paket_tmp = @paket_tmp
    paket_neu = "#{opts.download_dir}/#{version_neu}/paket/#{opts.manifest_name}.txt"

    FileUtils.mv( paket_tmp, paket_neu, force: true, verbose: true )

    return 0 # OK  
  end # method step2_copy
  
end # class Runner


end # module Upman
