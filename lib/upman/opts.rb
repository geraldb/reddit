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
    # note: do NOT include default .txt extension; rename to manifest_basename? why? why not??
    @manifest_name || 'paket'
  end

  ######################
  # install dirs  (root of app to get updated)
  #  - paket  (meta_dir/pack_dir)

  def install_dir=(value)
    @install_dir = value
  end

  def install_dir    #### - fix: use root_dir ??? why? why not?
    @install_dir || '.' 
  end

  def meta_dir    ## todo: rename to pack_dir ??? or add alias??
    "#{install_dir}/paket"
  end

  #################################
  # download (update) dirs - might not exist - check and create if missing
  #  - cache
  #  - tmp

  def download_dir
    path = "#{install_dir}/downloads"
    FileUtils.makedirs( path ) unless File.directory?( path )   # create dirs if not exists 
    path
  end

  def cache_dir
    path = "#{download_dir}/cache"
    FileUtils.makedirs( path ) unless File.directory?( path )   # create dirs if not exists 
    path
  end

  def tmp_dir
    path = "#{download_dir}/tmp"
    FileUtils.makedirs( path ) unless File.directory?( path )   # create dirs if not exists 
    path
  end


end # class Opts

end # module Upman
