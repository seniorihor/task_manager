require 'json'
require 'curb'

def url_path(url)
  unprotected = %w(login register)
  if unprotected.include?(url)
    adress = "http://task-manager-project.heroku.com/#{url}"
  else
    adress = "http://task-manager-project.heroku.com/protected/#{url}"
  end
end

def num(str)
	if str.to_i > 0
		return true
	end
	false
end

def content(args)
  array = args.split(' ')
  hash = Hash.new

  array.each do |el|
    if array.index(el)%2 == 0
	  if num(array[array.index(el)+1])
		hash[el] = (array[array.index(el)+1]).to_i
	  else
		hash[el] = array[array.index(el)+1]
	  end
    end
  end
  jdata = Hash.new
  jdata['taskmanager'] = hash
  puts  jdata.to_json
  jdata.to_json
end

# Menu
loop do
  puts 'Enter command:'
  case command = gets.chomp
  when 'new'
    puts "Adress:  "
    url = gets.chomp
    puts "Arguments: "
    args = gets.chomp

    response = Curl::Easy.http_post(url_path(url), content(args)) do |curl|
      curl.headers['Accept'] = 'application/json'
      curl.headers['Content-Type'] = 'application/json'
    end

    puts "#{url.capitalize}: #{response.response_code} #{response.body_str}"
  when 'exit'
    exit
  else
    puts 'Bad request'
  end
end
