require 'sinatra/base'
require 'rubygems'
require 'bundler/setup'
require '../models/User.rb'
require '../models/Task.rb'
require '../models/Friendship.rb'
require '../helpers/helpers.rb'
require '../config/data_mapper.rb'

class App < Sinatra::Base
	# Filters
	before do
  		content_type :json
	end
	# Protected means that users without rights, can't receive response from certain methods
	# @auth - indicator of authentication
	before '/protected/*' do
  		json_data = request.body.read

  		if json_data.empty?
    		@auth = false
  		else
    		@protected_hash = to_hash(json_data)
    		user = User.first(token: @protected_hash['taskmanager']['auth_token'])

    		if user.nil?
      			@auth = false
    		elsif user.deleted
     	 		@auth         = false
      			@restore_auth = true
    		else
      			@auth = true
    		end
  		end
	end

	# Login user
	post '/login' do
  		@hash = to_hash(request.body.read)

  		login(@hash['taskmanager']['login'],
        	  @hash['taskmanager']['password'])
	end

	# Logout user
	post '/protected/logout' do
  		return { logout: { error: '403 Forbidden' }}.to_json unless @auth

  		logout(@protected_hash['taskmanager']['auth_token'])
	end

	# Register user
	post '/register' do
 		 @hash = to_hash(request.body.read)

  		 if login_exists?(@hash['taskmanager']['login'])
   		 		{ register: { error: 'Login exists' }}.to_json
  		else
    		add_new_user(@hash['taskmanager']['login'],
            	     	 @hash['taskmanager']['password'],
            	     	 @hash['taskmanager']['firstname'],
            	     	 @hash['taskmanager']['lastname'])
  		end
	end

	# Delete user
	post '/protected/delete_user' do
  		return { delete_user: { error: '403 Forbidden' }}.to_json unless @auth

  		delete_user(@protected_hash['taskmanager']['auth_token'])
	end

	# Restore user
	post '/protected/restore_user' do
  		return { restore_user: { error: '403 Forbidden' }}.to_json unless @restore_auth

  		restore_user(@protected_hash['taskmanager']['auth_token'])
	end

	# Find user
	post '/protected/find_user' do
  		return { find_user: { error: '403 Forbidden' }}.to_json unless @auth

  		find_user(@protected_hash['taskmanager']['auth_token'],
       			  @protected_hash['taskmanager']['search_value'])
	end	

	# Add friend
	post '/protected/add_friend' do
  		return { add_friend: { error: '403 Forbidden' }}.to_json unless @auth

  		case @protected_hash['taskmanager']['priority']
  		when 4
    		add_new_task(@protected_hash['taskmanager']['auth_token'],
                 		 @protected_hash['taskmanager']['receiver_login'],
                 		 'Add me to friends!',
                 		 @protected_hash['taskmanager']['priority'])
  		when 5
    		add_friend(@protected_hash['taskmanager']['auth_token'],
               		   @protected_hash['taskmanager']['receiver_login'],
               		   @protected_hash['taskmanager']['friendship'])
  		else
    		{ add_friend: { error: 'Wrong priority' }}.to_json
  		end
	end

	# Delete friend
	post '/protected/delete_friend' do
  		return { delete_friend: { error: '403 Forbidden' }}.to_json unless @auth

  		delete_friend(@protected_hash['taskmanager']['auth_token'],
         	       	  @protected_hash['taskmanager']['receiver_login'])
	end

	# Create new task
	post '/protected/new_task' do
  		return { new_task: { error: '403 Forbidden' }}.to_json  unless @auth

  		case @protected_hash['taskmanager']['priority']
  		when 1..3
  		else
    		return { new_task: { error: 'Wrong priority' }}.to_json
  		end

  		add_new_task(@protected_hash['taskmanager']['auth_token'],
               		 @protected_hash['taskmanager']['receiver_login'],
               		 @protected_hash['taskmanager']['content'],
               		 @protected_hash['taskmanager']['priority'])
	end

	# Delete task
	post '/protected/delete_task' do
  		return { delete_task: { error: '403 Forbidden' }}.to_json unless @auth

  	delete_task(@protected_hash['taskmanager']['auth_token'],
              	@protected_hash['taskmanager']['task_id'])
	end

	# List all tasks
	post '/protected/get_task' do
  		return { get_task: { error: '403 Forbidden' }}.to_json unless @auth

  		get_task(@protected_hash['taskmanager']['auth_token'])
	end

end	