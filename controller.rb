# -*- coding: utf-8 -*-

require './model.rb'
require 'sinatra'	#-----------------------------------WHAT'S LEFT: JSON(should works:) ), SESSION (almost), FROM DATABASE(should works), VALIDATIONS, REGISTRATION(empty)----------------------------
require 'json'

use Rack::Session::Pool , :expire_after => 2592000

#------------------------------------------------------Filters-and-Helpers----------------------------------------------------------------


before do
	content_type :json
end

before '/protected/*' do
	if session[:curent_user].nil?
	 	@auth = false
	else
		@auth = true
	end
end

helpers do

	def loginExists(login)
		unless User.first(:username => login).nil?
			return {:loginExists => true}
		else
			return {:loginExists => false}
		end
	end

	def login(username, password)
		@user = User.new(username,password)
		if  username.empty? || password.empty?
			return {:login => false}.to_json
		elsif @user.login
			@user = User.first(:username => username)
			session[:curent_user] = @user
			return {:login => true}.to_json 							# Check user login in database (not empty login) => warning about []
		else										 # Allow user to login
			return {:login => false}.to_json
		end
	end

	def addNewTask(content,priority,whom,byWhom)
		@whom = User.first(:username => whom)
		@byWhom = session[:curent_user]
		if  content.empty? || priority.empty? 		# Ask, if nesessary validate 'whom' and 'byWhom' and if nesessary to validate same tasks (if will be some title)
			return {:newtask => false}
		else
			@task = Task.new(content,priority,)
			return {:newtask => true}
		end
	end

end

#-------------------------------------------------------------Routes----------------------------------------------------------------------


get '/login' do
	login(params[:username],password[:password])
end

post '/protected/newtask' do
	if @auth
		addNewTask( params[:content],
			   	      params[:priority],
			   	    	params[:whom],
			        	params[:byWhom],
			        	params[:title])
	else
		return {:auth => false}.to_json
	end
end

get '/protected/logout' do
	if @auth
		session.clear
		return {:logout => true}.to_json
	else
	    return {:auth => false}.to_json
	end
end
