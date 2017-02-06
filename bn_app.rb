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
  init_db
  @db.execute 'CREATE TABLE IF NOT EXISTS
				posts 
				(
					id          INTEGER PRIMARY KEY AUTOINCREMENT,
					CreatedDate DATE,
					Context     TEXT
				)'
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
#обработчик запроса get. браузер получает страницу с сервера
get '/new' do
  erb :new
end
#обработчик запроса post. браузер отправляет страницу на сервера
post '/new' do

  @new_post = params[:new_post]
  
	if @new_post ==""
		@error ='Это поле не может быть пустым'
		return erb :new
	end
  
end
