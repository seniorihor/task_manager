require 'json'
require 'curb'

def url_path(url)
	if url == 'login' || 'register'
		adress = 'http://task-manager-modular.herokuapp.com/'+url
	else
		adress = 'http://task-manager-modular.herokuapp.com/protected/'+url	
	end	
end

def str_to_json(args)
	array = args.split(' ')
	hash = Hash.new
	
	array.each do |el|
		if array.index(el)%2 == 0
			hash['taskmanager'][el] = array[array.index(el)+1]
		end		
	end 
	return hash.to_json
end

puts "ADRESS:  "
url = gets.chomp
puts "Arguments: "
args = gets.chomp

response = Curl::Easy.http_post(url_path(url), str_to_json(args)
    ) do |curl|
      curl.headers['Accept'] = 'application/json'
      curl.headers['Content-Type'] = 'application/json'
end

puts url+' Response : '+response.body_str
puts 'Response code : '+response.response_code.to_s

