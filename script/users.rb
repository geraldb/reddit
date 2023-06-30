####
#  to run use
#    $ ruby script/users.rb

##  webclient
$LOAD_PATH.unshift( "../../rubycocos/webclient/webclient/lib" )


require 'cocos'

### todo/fix:
##  move .env  loader to
##    cocos - why? why not?
def load_env( path='./.env' )
  if File.exist?( path )
     puts "==> loading .env settings..."
     env = read_yaml( path )
     puts "    applying .env settings... (merging into ENV)"
     pp env
     env.each do |k,v|
         ENV[k] ||= v
     end
  end
end

load_env




TOKEN_BASE_URL = 'https://www.reddit.com/api/v1/access_token'
API_BASE_URL   = 'https://oauth.reddit.com'



def download( username,
              after: nil,
              page: 1 )

headers = {
  'User-Agent'    => 'archiver/0.1 by geraldbauer',
  'Authorization' => "bearer #{ENV['REDDIT_TOKEN']}",
}

pp headers

# after = nil
# page = 1


loop do

  url = "https://oauth.reddit.com/user/#{username}/submitted?limit=100"
  url +=  "&after=#{after}"    if after

  res  = Webclient.get( url,
                         headers: headers )

  data = res.json
  pp data

  size = data['data']['children'].size
  dist = data['data']['dist']

  puts "==> page #{page}"
  puts "   #{size} record(s)"
  puts "   #{dist} dist (count)"

  after = data['data']['after']
  puts "   after: #{after}"



  name = "user-#{username.downcase}-submissions"
  name += ".#{page}"   if page

  write_json( "./cache/#{name}.json", data )

  puts " sleep 3 sec(s)"
  sleep( 3.0 )   ## sleep 3 secs


  break if after.nil?     ## size == 100

  page += 1
end
end



# download( 'geraldbauer', page: 17, after: 't3_pj0cl7' )
download( 'geraldbauer' )


puts "bye"

