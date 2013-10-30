# encoding: utf-8

#
# require 'java'     # Let's use some Java (needed for unzip)



module Upman

class Runner

  def initialize
    @logger = Logger.new( STDOUT )
    @logger.level = Logger::INFO
    @logger.formatter = proc { |severity, datetime, progname, msg| (['WARN', 'ERROR', 'FATAL'].include? severity) ? "*** #{severity}: #{msg}\n" : "#{msg}\n"  }
  
    @opts = Opts.new
  end

  attr :paket_alt_hash    # note: attr only creates readers (getters) 
  attr :paket_neu_hash
  attr :logger
  attr :opts


  def run( args )

    puts "upman version #{VERSION} on Ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"    
    
    optparse = OptionParser.new do |cmd|
    
      cmd.banner = "Usage: upman [options]"
    
      cmd.on( '-f', '--fetch URI', 'Download Server Source' ) do |uri|
        opts.fetch_base = uri
      end
    
      # todo: find different letter for debug trace switch (use v for version?)
      cmd.on( "-v", "--verbose", "Show debug trace" ) do
        logger.level = Logger::DEBUG
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
             step2_copy     if status == 0  
  end

  def step0_config
    logger.info "===== step 0: config"
  
    paket_alt = "#{opts.meta_dir}/paket.txt"
    paket_neu = "#{opts.download_dir}/paket.txt"

    if File.exists?( paket_alt ) == false
      logger.error "Unvollständige Installation (Manifest Datei 'paket.txt' nicht gefunden in META Ordner)"
      return 1 # Fehler
    end
  
    fetch_file( "paket.txt", paket_neu )

    if File.exists?( paket_neu ) == false
      logger.error "Unvollständiges Paket (Manifest Datei 'paket.txt' nicht gefunden in DOWNLOAD Ordner)"
      return 1 # Fehler
    end   

    @paket_alt_hash = YAML.load_file( paket_alt )  
    @paket_neu_hash = YAML.load_file( paket_neu )


    ## todo/fix: add debug option to toggle dumping of package hash

    puts "paket_neu_hash:"
    pp paket_neu_hash
  
    puts "paket_alt_hash:"
    pp paket_alt_hash
      
  
    # Download Paketversion muss >= Installation sein.

    version_alt = paket_alt_hash[ 'VERSION' ]  
    version_neu = paket_neu_hash[ 'VERSION' ]
  
    logger.info "VERSION:  #{version_alt} .. #{version_neu}"
 
    # convert version to number:
    #  version info format:  (2013.06r01) - <YYYY>.<MM>r<RELEASE>
    #     2013.06r01 becomes 20130601  for easy comparison using ints
    #     2013.05r02 becomes 20130502  etc.
    
    version_alt_num  =  version_alt.to_s.tr( '.', '' ).tr( 'r', '' ).tr( 't', '' ).tr( 'p', '' ).to_i
    version_neu_num  =  version_neu.to_s.tr( '.', '' ).tr( 'r', '' ).tr( 't', '' ).tr( 'p', '' ).to_i

    if version_alt_num > version_neu_num 
      logger.error "Downgrade nicht zulässig von Version #{version_alt} nach #{version_neu}."
      return 1 # Fehler
    end

    # Wechsel von Produktion auf Test unterbinden
  
    umgebung_alt = paket_alt_hash[ 'UMGEBUNG' ] 
    umgebung_neu = paket_neu_hash[ 'UMGEBUNG' ]

    logger.info "UMGEBUNG: #{umgebung_alt} .. #{umgebung_neu}"
      
    if umgebung_alt == 'PRODUKTION' && umgebung_neu != 'PRODUKTION'
       logger.error "Testpakete können nicht auf eine Produktionsversion installiert werden."
       return 1 # Fehler
    end

    return 0 # OK
  end


  def paket_on_update
    headers = ['VERSION', 'UMGEBUNG'] + opts.headers

    paket_alt_hash.each do | key, lines_alt |
      # skip these keys (e.g. VERSION, UMGEBUNG, etc.
      next   if headers.include?( key )
        
      lines_neu = paket_neu_hash[ key ]
    
      if lines_alt.nil? || lines_neu.nil?
        # check for corrupt paket.txt (key with no values)
        #  fix: check if first entry is empty => assume BOM (byte order mark) issue error/warning
        logger.warn( "Überspringe Datei/Key #{key} ohne Werte; Timestamp erwartet." )
        next
      end    
         
      values_alt = lines_alt.strip.split( ',' )
      values_neu = lines_neu.strip.split( ',' ) 
      
      value_alt = values_alt[ 0 ]  # assume first entry is checksum (md5 hash)
      value_neu = values_neu[ 0 ]

      # Nur neue Pakete holen
      if value_alt != value_neu
        logger.debug "#{key} => #{value_neu} != #{value_alt}"
        yield key, values_alt, values_neu        
      end
    end    
  end


  def step1_download
    logger.info "==== step 1: download"

    paket_on_update do |key, values_alt, values_neu|      
      fetch_file( key, "#{opts.download_dir}/#{key}" )
    end
    
    return 0 # OK  
  end # method step1_download
  

  def step2_copy
    logger.info "==== step 2: copy"
    
    paket_on_update do |key, values_alt, values_neu|      
      next if values_neu.length < 2   # we need at least to parameters for copy operation (2nd para has copy instructions)
      
      copy_values = values_neu[1].strip.split( ' ' )
      if copy_values.length == 2
        copy_op     = copy_values[0].strip
        copy_dest   = copy_values[1].strip
         
        if copy_op.downcase == 'clean'
          unzip_file( "#{opts.download_dir}/#{key}", "#{opts.install_dir}/#{copy_dest}" )
        elsif copy_op.downcase == 'update'
          unzip_file( "#{opts.download_dir}/#{key}", "#{opts.install_dir}/#{copy_dest}" )
        else
          logger.error 'Unknown copy operation in instruction in paket.txt. Expected clean|update'
        end
      else
        logger.error 'Invalid copy instruction in paket.txt. Expected zip|file ziel'
      end      
    end
    
    return 0 # OK  
  end # method step2_copy

############################################
##
## "built-in" helper methods
##  

  def copy_file( src, dest )
    logger.info "copy file src => #{src}, dest => #{dest}"

=begin  
    FileUtils.makedirs( File.dirname( dest ))  # todo: check if dir exists
    FileUtils.cp src, dest                     # todo: check for overwrite/force option??
=end
  end


  def copy_input_stream( input,  output )  # InputStream, OutputStream
=begin
    buffer = Java::byte[1024].new
 
    while (len = input.read( buffer )) >= 0 do
      output.write(buffer, 0, len)
    end
  
    input.close()
    output.close()
=end
  end


  ## todo: catch IOException

  def unzip_file( src, dest_dir )
  
    logger.info "unzip file src => #{src}, dest dir => #{dest_dir}"

    # Enumeration entries
    # ZipFile zipFile

=begin      
    zipFile = java.util.zip.ZipFile.new( src )
  
    entries = zipFile.entries()  # returns Enumeration
  
    while entries.hasMoreElements() do
      entry = entries.nextElement()   # returns ZipEntry
  
      if entry.isDirectory() then
        logger.debug "  extracting directory: #{entry.getName()}"         
        next
      end
  
      logger.debug "  extracting file: #{entry.getName()}"
     
      dest = "#{dest_dir}/#{entry.getName()}"
          
      FileUtils.makedirs( File.dirname( dest )) # todo: check if dirs exists
     
      input  = zipFile.getInputStream( entry )
      output = java.io.BufferedOutputStream.new( java.io.FileOutputStream.new( dest ))
        
      copy_input_stream( input, output )
    end # end while
      
    zipFile.close()
=end
  end # method unzip_file

  # lets you change update (server )base using -f/--fetch URI switch


  def fetch_file( src_without_base, dest )
    
    src = "#{opts.fetch_base}/#{src_without_base}"
  
    logger.info "fetch file src => #{src}, dest => #{dest}"
  
    if src.include?( 'http://' ) == false
      # for non-http uris use File copy
      FileUtils.makedirs( File.dirname( dest ))  # todo: check if dir exists
      FileUtils.cp src, dest                     # todo: check for overwrite/force option??
      return
    end
    
    # todo/fix: unterstuetzt derzeit keinen download ueber proxy
  
    uri = URI.parse( src )
    http = Net::HTTP.new( uri.host, uri.port )
    request = Net::HTTP::Get.new( uri.request_uri, { 'User-Agent'=> 'upman'} )
    
    response = http.request( request )
  
    if response.code == '200'
      msg = "#{response.code} #{response.message}"
      logger.debug "#{msg}"

      logger.debug "content_type: #{response.content_type}, content_length: #{response.content_length}"
  
    ## todo/fix: check content type for zip,exe,dll (needs binary?)
    
    
=begin    
    # check for content type; use 'wb' for images
    if response.content_type =~ /image/
      logger.debug 'switching to binary'
      flags = 'wb'
    else
      flags = 'w'
    end
=end

      # always use binary
      flags = 'wb'


      File.open( dest, flags ) do |f|
        f.write( response.body )
      end       
    else
      msg = "#{response.code} #{response.message}"
      logger.error "#{msg}"
      # fix/todo: raise exception!!!
    end
  end # end method fetch file
  
end # class Runner


end # module Upman
