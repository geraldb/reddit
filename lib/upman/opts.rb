module Upman

class Opts

  # extra headers for manifest
  #  - headers get ignored (assumed NOT to be files that get md5 checksum/digest/hash calculated)
  def headers=(value)
    # NB: value is supposed to be an array of strings
    @headers = value
  end

  ## fix/todo:
  ##  also make it into a command line option!!
  
  def headers
    # NB: return value is supposed to be an array of strings
    @headers || []
  end


  def fetch_base=(value)
    @base = value
  end
  
  def fetch_base
    @base  ##  || 'http://example.com/packages' ???
  end


  def manifest_name=(value)
    @manifest_name = value
  end

  def manifest_name
    @manifest_name || 'paket'     # note: do NOT include default .txt extension; rename to manifest_basename? why? why not??
  end


  def install_dir    #### - fix: use root_dir ??? why? why not?
    # NB: assume current  working dir is $INSTALL_DIR/SYS
    path = File.expand_path( '..' )
    path
  end
  
  def download_dir
    path = "#{install_dir}/downloads"
    FileUtils.makedirs( path ) unless File.directory?( path )   # create dirs if not exists 
    path
  end

  def meta_dir    ## todo: rename to package_dir ???
    "#{install_dir}/paket"
  end

end # class Opts

end # module Upman
