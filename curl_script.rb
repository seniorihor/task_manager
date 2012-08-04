require 'json'
require 'curb'
Curl::CURL_USESSL_NONE

def url_path(url)
	if url == 'login' || 'register'
		adress = 'https://task-manager-modular.herokuapp.com/'+url
	else
		adress = 'https://task-manager-modular.herokuapp.com/protected/'+url	
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
	hash.to_json
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