
require 'cocos'



# data = read_json( './cache/submissions-diypunkart.11.json')
data = read_json( './cache/submissions-diypopart.1.json')


puts "records:"
pp data['data']['children'].size
# puts "error:"
# pp data['error']


data['data']['children'].each_with_index do |h,i|
    rec = h['data']
    id = "#{h['kind']}_#{rec['id']}"
  puts "==> #{i+1} - #{rec['title']}"
  puts "   author:       #{rec['author']}"
  puts "   num_comments: #{rec['num_comments']}"
  puts "   id: #{id}"

   ## "created_utc": 1677248237,
   created = rec['created_utc']
   print "   "
   print  Time.at( created )
   print "  --  "
   print  created
   print "\n"
end


puts "bye"