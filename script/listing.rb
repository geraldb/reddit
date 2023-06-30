##################
#  split submissions listings
#


require 'cocos'



def export_submissions( data )


puts "records:"
pp data['data']['children'].size
# puts "error:"
# pp data['error']


data['data']['children'].each_with_index do |h,i|
    rec = h['data']
    id = "#{h['kind']}_#{rec['id']}"

    ## "created_utc": 1677248237,
   created = rec['created_utc']

    subreddit = rec['subreddit']
    author    = rec['author']
    ts  =  Time.at( created ).utc
    ts2  =  Time.at( created.to_i ).utc

    puts "==> #{i+1} - #{rec['title']}"

   print "   "
   print ts
   print " / "
   print ts2
   print "  --  "
   print  created
   print "\n"

  puts "   author:       #{author}"
  puts "   num_comments: #{rec['num_comments']}"
  puts "   post_hint:    #{rec['post_hint']}"
  puts "   id: #{id}"


   name = "#{subreddit.downcase}/#{author.downcase}-#{ts.strftime('%Y-%m-%d')}-#{id}"
   puts name

   path = "./archive/#{name}.json"
   write_json( path, rec )
end
end



# data = read_json( './cache/submissions-diypunkart.11.json')
# data = read_json( './cache/submissions-diypopart.1.json')
# data = read_json( './cache/submissions-diypunkart.1.json')
data = read_json( './cache/submissions-rightclicksavethis.1.json')

export_submissions( data )

puts "bye"