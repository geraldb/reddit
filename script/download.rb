####
#  to run use
#    $ ruby script/download.rb



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



def download( subreddit, after: nil,
                         page: 1 )

headers = {
  'User-Agent'    => 'archiver/0.1 by geraldbauer',
   'Authorization' => "bearer #{ENV['REDDIT_TOKEN']}",
}

pp headers



## add optioanl limit (batch)
##   ?limit=100
##  default page size/limit is 25 ??

##
## note: use
##        "public" version w/o token
##
##   e.g.
##     https://www.reddit.com/r/DIYPunkArt/new.json?limit=100
##     https://www.reddit.com/r/DIYPunkArt/new.json?limit=100&after=t3_vzjr8q


##
##  save submissions one-by-one
##    for filename use:
##     -  author       -  e.g.  downcased  (need to slug-ified too?)
##     -  created_utc? - e.g. 2022-11-25
##     -  id ?  - e.g.  _xxeee
##
##   comment or submssion
##  cache/diypunksart/geraldbauer--2022-11-22--#{kind e.g. t3/t2}_dddd.json
##



loop do

   url = "https://oauth.reddit.com/r/#{subreddit}/new?limit=100"
   url +=  "&after=#{after}"    if after

##     https://www.reddit.com/r/DIYPunkArt/new.json?limit=100
##     https://www.reddit.com/r/DIYPunkArt/new.json?limit=100&after=t3_vzjr8q

 ##  url = "https://www.reddit.com/r/#{subreddit}/new.json?limit=100"
 ##  url +=  "?after=#{after}"    if after


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



  name = "submissions-#{subreddit.downcase}"
  name += ".#{page}"   if page

  write_json( "./api/#{name}.json", data )

  puts " sleep 3 sec(s)"
  sleep( 3.0 )   ## sleep 3 secs

  break if after.nil?     ## size == 100
  ## break unless size == 100

  page += 1
end
end


def download_comments_by( user, after: nil,
                                page: 1 )

headers = {
  'User-Agent'    => 'archiver/0.1 by geraldbauer',
  'Authorization' => "bearer #{ENV['REDDIT_TOKEN']}",
}

pp headers



## add optioanl limit (batch)
##   ?limit=100
##  default page size/limit is 25 ??

##
## note: use
##        "public" version w/o token
##
##   e.g.
##     https://www.reddit.com/user/geraldbauer/comments.json?limit=100

loop do

#  url = "https://www.reddit.com/user/#{user}/comments.json?limit=100"
#  url +=  "?after=#{after}"    if after

   url = "https://oauth.reddit.com/user/#{user}/comments?limit=100"
   url +=  "?after=#{after}"    if after


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



  name = "comments-#{user.downcase}"
  name += ".#{page}"   if page

  write_json( "./api/#{name}.json", data )

  puts " sleep 3 sec(s)"
  sleep( 3.0 )   ## sleep 3 secs


  ## break if after.nil?     ## size == 100
  break unless size == 100

  page += 1
end
end





## download( 'DIYPunkArt' )
## download( 'DIYPopArt' )
## download( 'RightClickSaveThis' )
## download( 'planetruby' )
## download( 'CryptoKittiesDev' )

download_comments_by( 'geraldbauer' )

## download( 'CryptoPunksDev' )
# {"reason"=>"banned", "message"=>"Not Found", "error"=>404}


puts "bye"



__END__

DIYPunkArt

==> page 2
   25 record(s)
   25 dist (count)
   after: t3_wlyg1i


planet ruby
==> page 1
   29 record(s)
   29 dist (count)








geraldbauer
6,399 post karma
776 comment karma
subreddit	post	comment


CryptoPunksDev	385	106
DIYPunkArt	13	12
DIYPopArt
planetruby	11	0
CryptoKittiesDev	1	2
RightClickSaveThis	1	1


CryptoKitties	241	120
MoonCatRescue	126	20
BitcoinOrdinals	8	2
24px	10	-1

ruby	3374	392
javascript	890	63
opendata	345	4
datasets	201	8
Jekyll	177	30
Python	127	35
rails	180	-20
ethdev	43	6
BlockChain	41	8
tezos	39	0
Buttcoin	29	10
litecoin	31	-1
CryptoTechnology	23	2
cryptopunks	20	3
ethereum	8	14
LaTeX	15	0
BlockchainGame	8	5
golang	10	2
worldcup	8	0
semanticweb	6	2
webdev	1	7
cryptulips	6	0
sqlite	5	0
imagemagick	4	1
cryptopunk	5	0
hyperledger	3	0
Tetherino	3	0
web_design	1	3
pdf	3	0
codegolf	3	0
CryptoCurrency	1	1
PunkArt	2	0
podcasting	2	0
json	2	0
podcast	2	0
PostgreSQL	2	0
graphql	2	0
CryptoKittiesMarket	1	0
moonbirds	1	0
libra	1	0
ModSupport	1	0
Austria	3	-15
Bitcoin	1	-15
PixelArt	1	-31




# after  = 't3_wskxi2'
# page = 2
# after = 't3_wddm81'
# page = 3
# after = 't3_w62iu9'
# page = 4

# after = 't3_vzjr8q'
# page = 5

# after = 't3_vsmyi5'
# page = 6

# after = 't3_vl0rq2'
# page = 7


after = 't3_vejqhh'
page = 8


url = "https://oauth.reddit.com/r/#{subreddit}/new"
url +=  "?after=#{after}"    if after

res  = Webclient.get( url,
                       headers: headers )

data = res.json
## pp data

name = "submissions-#{subreddit.downcase}"
name += ".#{page}"   if page

write_json( "./api/#{name}.json", data )


puts "bye"



