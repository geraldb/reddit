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
    if status == 0 
      puts "*** OK: step0_config"
      status = step1_download 
      if status == 0
        puts "*** OK: step1_download"
        status = step2_copy
        if status == 0
          puts "*** OK: step2_copy"
        else
          puts "*** FAIL: step2_copy"
        end
      else
        puts "*** FAIL: step1_download"
      end
    else
      puts "*** FAIL: step0_config"
    end

  end # method run



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


  def step1_download
    logger.info "==== step 1: download"

    ## todo: use latest ?? or just use no folder ??? 
    version_neu = paket_neu_hash[ 'VERSION' ] || 'latest'

    dl = Downloader.new( opts.fetch_base, opts.download_dir )

    packup = PackUpdateCursor.new( paket_alt_hash, paket_neu_hash, opts.headers )
    packup.each do |key, values_alt, values_neu|
      
      entry_key = key
      entry_md5 = values_neu[0]
      
      ## check if exists alread in pack version
      ## if yes, skip    -- move into dl.process ??? why? why not?
      entry_pack = "#{opts.download_dir}/#{version_neu}/paket/#{key}" 

      if File.exists?( entry_pack ) && calc_digest_md5( entry_pack ) == entry_md5
        logger.info "*** skipping manifest entry #{entry_pack}; unzipped entry exists already w/ matching m5 hash"
        next   # file already downloaded n unzipped -  in place; md5 match
      end

     ok = dl.process( entry_key, entry_md5 )
     
     if ok
       logger.debug "  OK entry #{entry_key}"
     else
       logger.debug "  !!! FAIL entry #{entry_key}"
       return 1  # on error return; break
     end
     
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
    FileUtils.makedirs( "#{opts.download_dir}/#{version_neu}/paket" )   unless File.directory?( "#{opts.download_dir}/#{version_neu}/paket" )

    packup = PackUpdateCursor.new( paket_alt_hash, paket_neu_hash, opts.headers )
    packup.each do |key, values_alt, values_neu|

      if values_neu.length < 2   # we need at least two parameters for copy operation (2nd para has copy instructions)
         logger.error 'missing operation spec; expected min two values/args'
         next
      end

      entry_md5   = values_neu[0]
      copy_values = values_neu[1].strip.split( ' ' )
      if copy_values.length == 2
        copy_op     = copy_values[0].strip
        copy_dest   = copy_values[1].strip

        ## todo/fix - check: if paket/key exists? if yes, assume already unzipped
        ##   - moved zip is confirmation
        ##   - lets us resume unpack and try again and again etc.

        if copy_op.downcase == 'clean'

          ## check if zip exists in /paket? if yes, assume already unzipped
          ##  - convention:  assume moved zip is confirmiation of success
          #
          # todo/fix: check for md5 tooo!!! if file exists -must match - if not!!! move to trask and unpack again!!!
          
          if File.exist?( "#{opts.download_dir}/#{version_neu}/paket/#{key}" )
            ## assume zip exists; do nothing
            logger.info "assuming unpacked zip exists; skip - do nothing"
          else
            unzip_file( "#{opts.download_dir}/tmp/#{key}_#{entry_md5}", "#{opts.download_dir}/#{version_neu}/updates/#{copy_dest}" )
          
            ## on success - move zip from /tmp to /paket
            FileUtils.mv( "#{opts.download_dir}/tmp/#{key}_#{entry_md5}", "#{opts.download_dir}/#{version_neu}/paket/#{key}", force: true, verbose: true )
          end

        elsif copy_op.downcase == 'update'

          # todo/fix: check for md5 tooo!!! if file exists -must match - if not!!! move to trask and unpack again!!!
          
          if File.exist?( "#{opts.download_dir}/#{version_neu}/paket/#{key}" ) 
            ## assume zip exists; do nothing
            logger.info "assuming unpacked zip exists; skip - do nothing"
          else
            unzip_file( "#{opts.download_dir}/tmp/#{key}_#{entry_md5}", "#{opts.download_dir}/#{version_neu}/patches/#{copy_dest}" )

            ## on success - move zip from /tmp to /paket
            FileUtils.mv( "#{opts.download_dir}/tmp/#{key}_#{entry_md5}", "#{opts.download_dir}/#{version_neu}/paket/#{key}", force: true, verbose: true )
          end
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
