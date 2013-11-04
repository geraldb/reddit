
module Upman::Utils


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


  def calc_digest_md5( fn )
    md5 = Digest::MD5.hexdigest( File.open( fn, 'rb') { |f| f.read } )
    md5
  end


  ## todo: catch IOException

  def unzip_file( src, dest_dir )
    
    ## using rubyzip
    ### -- examples see http://stackoverflow.com/questions/966054/how-to-overwrite-existing-files-using-rubyzip-lib
    
    logger.info "unzip file src => #{src}, dest dir => #{dest_dir}"

    Zip::File.open( src ) do |zipfile|
      
      ## todo: check if each also returns entries for folders/dirs???
      
      zipfile.each do |entry|
        full_path = File.join( dest_dir, entry.name )
        puts "  unpack #{entry.name}"
        FileUtils.mkdir_p( File.dirname( full_path ) )
        zipfile.extract( entry, full_path ) { true }    # note: will overwrite file if exists
      end
    end
  end


  def unzip_file_old( src, dest_dir )
  
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



  def fetch_file( src, dest )

    logger.info "fetch file src => #{src}, dest => #{dest}"
  
    if src.include?( 'http://' ) == false
      # for non-http uris use File copy
      FileUtils.makedirs( File.dirname( dest ))  # todo: check if dir exists
      FileUtils.cp src, dest                     # todo: check for overwrite/force option??
      return true
    end

    response = Fetcher::Worker.new.get_response( src )

    # on error return false; do NOT copy file; sorry
    return false   if response.code != '200'

    ## todo/fix: check content type for zip,exe,dll (needs binary?)
    ##  fix: default to binary!! and just use 'w' for text/hypertext and text/text, for example
#    if response.content_type =~ /image/
#      logger.debug '  switching to binary'
#      flags = 'wb'
#    else
#      flags = 'w'
#    end

    ## -- always safe a binary (as is) for now
    flags = 'wb'
 
  
    File.open( dest, flags ) do |f|
      f.write( response.body )
    end

    return true
  end


end # module Upman::Utils
