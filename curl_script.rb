require 'json'
require 'curb'

puts "ADRESS:  "
url = gets.chomp

puts "Arguments: "
args = gets.chomp
array = args.split(' ')
hash = Hash.new

array.each do |el|
	if array.index(el)%2 == 0
		hash[el] = array[array.index(el)+1]
	end		
end 

jdata = Hash.new
jdata['taskmanager'] = hash

if url == 'login' || 'register'
	adress = 'http://task-manager-modular.herokuapp.com/'+url
else
	adress = 'http://task-manager-modular.herokuapp.com/protected/'+url	
end	
	
response = Curl::Easy.http_post(adress, jdata.to_json
    ) do |curl|
      curl.headers['Accept'] = 'application/json'
      curl.headers['Content-Type'] = 'application/json'
end
puts url+' Response : '+response.body_str
puts 'Response code : '+response.response_code.to_s