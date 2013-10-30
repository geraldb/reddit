

require 'upman/version'  # let it always go first


module Upman

  def self.banner
    "upman/#{VERSION} on Ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
  end

=begin
  def self.root
    "#{File.expand_path( File.dirname(File.dirname(__FILE__)) )}"
  end
=end

end  # module Upman


puts Upman.banner    # say hello

