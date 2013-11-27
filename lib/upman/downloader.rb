# encoding: utf-8


module Upman

class Downloader

  include LogUtils::Logging
  
  include Utils  # e.g. fetch_file, unzip_file etc  - use FileUtils instead  - why ??? why not???

  def initialize( fetch_base, dest_root )
    @fetch_base = fetch_base
    @dest_root  = dest_root
    
    @cache_dir  = "#{@dest_root}/tmp"
  end


  def process( entry_key, entry_md5 )

    entry_uri = "#{@fetch_base}/#{entry_key}"

    ts = Time.now.strftime('%Y-%m-%d_%H.%M-%S')
    entry_tmp = "#{@cache_dir}/__#{ts}__#{entry_key}_#{entry_md5}_tmp"   # download in progess
    
    ## todo: entry_new change to entry_cache
    entry_new = "#{@cache_dir}/#{entry_key}_#{entry_md5}"            # done - md5 check ok - just move/mv (rename) tmp to new

    ## todo: check if file exists w/ valid md5 in tmp/paket/ folder
    #   resume and skip to next file!
    if File.exists?( entry_new ) && calc_digest_md5( entry_new ) == entry_md5
      logger.info "*** skipping manifest entry #{entry_key}; download exists already w/ matching m5 hash"
      return true   # true-success    => file already downloaded/in place; md5 match
    end

    ok = fetch_file( entry_uri, entry_tmp )

    if ok
      puts "  OK fetch_file #{entry_key}"
    else
      puts "  !!! FAIL fetch_file #{entry_key}"
      return false   # false-error  - error on http download
    end

    # if checksum ok move to final destination!!
    entry_md5_tmp = calc_digest_md5( entry_tmp )
    if entry_md5 == entry_md5_tmp
      FileUtils.mv( entry_tmp, entry_new, :force => true, :verbose => true )
      puts "  OK md5 match/check - #{entry_key}"
    else
      logger.debug " !!! FAIL md5 mismatch - expected: #{entry_md5} <=>  actual: #{entry_md5_tmp}"
      return false  # false-error
    end

    return true  # true-success
  end

  
end # class Downloader

end # module Upman
