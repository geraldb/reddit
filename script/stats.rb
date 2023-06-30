
require 'cocos'



# data = read_json( 'submissions-diypunkart.json')
data = read_json( 'submissions-cryptopunksdev.json')


puts "records:"
pp data['data'].size
puts "error:"
pp data['error']


data['data'].each_with_index do |rec,i|
  puts "==> #{i+1}/#{data['data'].size} - #{rec['title']}"
  puts "   author:       #{rec['author']}"
  puts "   num_comments: #{rec['num_comments']}"

   ## "created_utc": 1677248237,
   created = rec['created_utc']
   print "   "
   print  Time.at( created )
   print "  --  "
   print  created
   print "\n"
end


puts "bye"