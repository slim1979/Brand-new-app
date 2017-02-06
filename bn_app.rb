require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'

def init_db
	@db = SQLite3::Database.new 'bn_app.db'
	@db.results_as_hash = true
end
before do
	init_db
end
configure do
  enable :sessions
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Wrong login/password. Sorry, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  erb 'Can you handle a <a href="/secure/place">secret</a>?'
end

get '/login/form' do

		erb :login_form
  
end

post '/login/attempt' do

	@login = params[:username]
	@password = params[:user_password]
	
	if @login == 'admin' && @password == 'secret'
		session[:identity] = params[:username]
		erb :welcome
		#erb 'This is a secret place that only <%=session[:identity]%> has access to!'
	else
		@message = "Access denied"
		where_user_came_from = session[:previous_url] || '/'
		redirect to where_user_came_from
	end   
   
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/new' do
  erb :new
end
post '/new' do

  @new_post = params[:new_post]
  
  erb "Вы ввели #{@new_post}"
  
end
