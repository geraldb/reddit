# encoding: utf-8

module Upman


module State
  UNKNOWN       = 0    # start state
  UP_TO_DATE    = 1
  NEW_VERSION   = 2    # new version ready - find a better name - state??
  ERROR         = 9
end  # module State


class Runner


  include LogUtils::Logging
  
  include Utils  # e.g. fetch_file, unzip_file etc  - use FileUtils instead  - why ??? why not???

  def initialize
    @opts  = Opts.new
    @state = State::UNKNOWN   # undefined (unknown) state - needs to run first
    @error_msg = ''   # last error message
  end

  # -- start state
  def unknown?()     @state == State::UNKNOWN;     end
  
  # -- end states
  def up_to_date?()   @state == State::UP_TO_DATE;   end
  def new_version?()  @state == State::NEW_VERSION;  end
  def error?()        @state == State::ERROR;        end
  
  def error_msg()    @error_msg;   end
  
  def error( msg )   # report error
    logger.error "  !!! *** #{msg}"
    @error_msg = msg
    @state = State::ERROR
  end


  attr :paket_alt_hash    # note: attr only creates readers (getters) 
  attr :paket_neu_hash
  attr :opts



  def run( args )
    
    # resest state to unkownn
    @state = State::UNKNOWN   # undefined (unknown) state - needs to run first
    @error_msg = ''    # rest last error message

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
      
    status = step0a_load_manifests    # get install and new manifests; only continue if status is OK, that is, 0
    unless status == 0
      puts "!!! *** FAIL: step0a_load_manifests"
      return status    # failure code
    end


    ############################### 
    # quick check #1
    #   -- pack already prepared and ready to merge?
    #      check if manifest exists in latest or <version> meta folder

    version_neu = paket_neu_hash[ 'VERSION' ] || 'latest'   # todo: use latest ?? or just use no folder ??? 
    paket_neu = "#{opts.download_dir}/#{opts.manifest_name}-#{version_neu}/paket/#{opts.manifest_name}.txt"

    if File.exist?( paket_neu )
      ## use /force flag or /clean to force full/clean install/update
      logger.info "OK -- prepared pack in place ready for merge - >#{opts.manifest_name}.txt<; do nothing"
      @state = State::NEW_VERSION
      return 0
    end

    ########################
    # quick check #2
    #  -- up-to-date (version match and md5 entries match)

    packup = PackUpdateCursor.new( paket_alt_hash, paket_neu_hash, opts.headers )
    if packup.up_to_date?
      logger.info "OK -- up-to-date - >#{opts.manifest_name}.txt<; do nothing"
      @state = State::UP_TO_DATE
      return 0
    end

    status = step0b_config
    if status == 0 
      puts "OK -- step0b_config"
      status = step1_download 
      if status == 0
        puts "OK -- step1_download"
        status = step2_copy
        if status == 0
          puts "OK -- step2_copy"
          @state = State::NEW_VERSION     # assume everything is ok; new version ready!
        else
          puts "!!! *** FAIL: step2_copy"
        end
      else
        puts "!!! *** FAIL: step1_download"
      end
    else
      puts "!!! *** FAIL: step0_config"
    end

  end # method run


  def step0a_load_manifests
    logger.info "===== step 0a: load manifests"
  
    paket_alt = "#{opts.meta_dir}/#{opts.manifest_name}.txt"

    unless File.exist?( paket_alt )
      error "Unvollständige Installation (Manifest Datei >#{opts.manifest_name}.txt< nicht gefunden in META Ordner '#{opts.meta_dir}')"
      return 1 # Fehler
    end

    paket_neu_fetch_uri = "#{opts.fetch_base}/#{opts.manifest_name}.txt"

    response = Fetcher::Worker.new.get_response( paket_neu_fetch_uri )

    unless response.code == '200'
      error "failed to fetch manifest file >#{opts.manifest_name}.txt<"
      return 1  # Fehler
    end

    @paket_neu_text = response.body  # todo: do we need to call respone.body.read (e.g. use .read)


    @paket_alt_hash = PackManifest.load_file( paket_alt )
    # load from string - not yet saved to disk - do NOT fill up tmp folder for every check (just keep it in memory)
    @paket_neu_hash = PackManifest.load( @paket_neu_text )   


    ## todo/fix: add debug option to toggle dumping of package hash

    puts "paket_neu_hash:"
    pp paket_neu_hash
  
    puts "paket_alt_hash:"
    pp paket_alt_hash
    
    return 0  # 0-OK/SUCCESS  
  end


  def step0b_config

    ####################################################
    # check #1
    #   production only allows production packs e.g. 
    #  -- no downgrade to test or other allowed
  
    umgebung_alt = paket_alt_hash[ 'UMGEBUNG' ] 
    umgebung_neu = paket_neu_hash[ 'UMGEBUNG' ]

    logger.info "UMGEBUNG: #{umgebung_alt} => #{umgebung_neu}"
  
    if umgebung_alt && umgebung_neu
       if umgebung_alt == 'PRODUKTION' && umgebung_neu != 'PRODUKTION'
         error "Testpakete können nicht auf eine Produktionsversion installiert werden."
         return 1 # Fehler
       end
    end


    ####################################################
    # check #2
    #  download Paketversion muss >= Installation sein (in production only)
    # --  in produktion do NOT allow downgrade etc.

    version_alt = paket_alt_hash[ 'VERSION' ]
    version_neu = paket_neu_hash[ 'VERSION' ]
  
    logger.info "VERSION:  #{version_alt} => #{version_neu}"

    if umgebung_alt == 'PRODUKTION' && (version_alt && version_neu)
      # convert version to number:
      #  version info format:  (2013.06r01) - <YYYY>.<MM>r<RELEASE>
      #     2013.06r01 becomes 20130601  for easy comparison using ints
      #     2013.05r02 becomes 20130502  etc.

      version_alt_num  =  version_alt.to_s.gsub( /[a-z\-._]/i, '' ).to_i
      version_neu_num  =  version_neu.to_s.gsub( /[a-z\-._]/i, '' ).to_i

      logger.info "VERSION NUM: #{version_alt_num} => #{version_neu_num}"

      if version_alt_num > version_neu_num 
        error "Downgrade in Produktion nicht zulässig von Version #{version_alt} nach #{version_neu}."
        return 1 # Fehler
      end
    end

    return 0 # OK
  end



  def step1_download
    logger.info "==== step 1: download"

    dl = Downloader.new( opts.fetch_base, opts.tmp_dir, opts.cache_dir )

    packup = PackUpdateCursor.new( paket_alt_hash, paket_neu_hash, opts.headers )
    packup.each do |key, values_alt, values_neu|
      
      entry_key = key
      entry_md5 = values_neu[0]

      ok = dl.process( entry_key, entry_md5 )
     
      if ok
        logger.debug "  OK entry #{entry_key}"
      else
        error "FAIL entry #{entry_key}"
        return 1  # 1-error - on error return; break
      end
     
    end

    return 0 # 0-OK-succes  
  end # method step1_download



  def step2_copy
    logger.info "==== step 2: copy"


    ## todo: use latest ?? or just use no folder ??? 
    version_neu = paket_neu_hash[ 'VERSION' ] || 'latest'

    updates_dir = "#{opts.download_dir}/#{opts.manifest_name}-#{version_neu}/updates"    ## use updates_root ??
    patches_dir = "#{opts.download_dir}/#{opts.manifest_name}-#{version_neu}/patches"    ## use patches_root ??
    paket_dir   = "#{opts.download_dir}/#{opts.manifest_name}-#{version_neu}/paket"

    # -- make sure folders updates n patches exist
    FileUtils.makedirs( updates_dir ) unless File.directory?( updates_dir )
    FileUtils.makedirs( patches_dir ) unless File.directory?( patches_dir )
    FileUtils.makedirs( paket_dir )   unless File.directory?( paket_dir )


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

        entry_ack   =  "#{paket_dir}/#{key}_#{entry_md5}"
        if File.exist?( entry_ack )
          ## assume zip already unpacked!; do nothing
          logger.info "assuming zip >#{key}< already unpacked; skip - do nothing"
          next
        end
        
        entry_cache = "#{opts.cache_dir}/#{key}_#{entry_md5}"
        
        if copy_op.downcase == 'clean'
          entry_dest  = "#{updates_dir}/#{copy_dest}"
        elsif copy_op.downcase == 'update'
          entry_dest  = "#{patches_dir}/#{copy_dest}"
        else
          logger.error '***** Unknown copy operation in instruction in paket.txt. Expected clean|update'
          ## todo: make it into an error e.g. return 1 ?? why? why not??
          next
        end
        
        ## note: on retry should just overwrite!! - check if it works  
        unzip_file( entry_cache, entry_dest )

        ## on success - add acknowledgment/confirmation file
        ## -- just create an empty file -- add anything to the file -why? why not?? use append mode (a)??
        File.open( entry_ack, 'w') do |f|
          # do nothing; empty file
        end  
      else
        logger.error '***** Invalid copy instruction in paket.txt. Expected zip|file ziel'
        ## todo: make it into an error e.g. return 1?? why? why not??
      end
    end


    ## on success - save paket.txt as last step;
    #  note: if it exists already - we will overwrite it

    ## note: !!!!!! always safe a binary for now
    ##  -- otherwise we get mixed up w/ cr lf and so on

    paket_neu = "#{paket_dir}/#{opts.manifest_name}.txt"
    File.open( paket_neu, 'wb' ) do |f|
      f.write @paket_neu_text
    end

    return 0 # OK  
  end # method step2_copy
  
end # class Runner


end # module Upman
