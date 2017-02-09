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
				"authors" 
				(
					id          		INTEGER PRIMARY KEY AUTOINCREMENT,
					Registration_date	DATE,
					Author_name 		TEXT					
				)'
  @db.execute 'CREATE TABLE IF NOT EXISTS
				"posts" 
				(
					id          INTEGER PRIMARY KEY AUTOINCREMENT,
					CreatedDate DATE,
					Author_name TEXT,
					Header		TEXT,
					Context     TEXT
				)'
	@db.execute 'CREATE TABLE IF NOT EXISTS
				"comments" 
				(
					id          INTEGER PRIMARY KEY AUTOINCREMENT,
					CreatedDate DATE,
					user_name   TEXT,
					Context     TEXT,
					post_id 	INTEGER
				)'
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before '/new' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Для добавления статей нужно авторизоваться!'
    halt erb(:login_form)
  end
end

get '/' do
	
  init_db
  #добавляем в переменную все посты с аргументом desc для вывода их
  #на экран в обратном порядке, т.е. самые свежие посты будут наверху списка
  @outpost = @db.execute 'select * from posts order by id desc'
  
  @out_comments = @db.execute 'select id from comments order by post_id'
  
  erb :index
end

get '/login/form' do

		erb :login_form
  
end

post '/login/attempt' do

	@login = params[:username]
	@password = params[:user_password]
	
	if @login == 'admin' && @password == 'secret'
		session[:identity] = params[:username]
		erb :new
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

#здесь добавляются и проверяются на заполнение новые посты.
#обработчик запроса post. браузер отправляет страницу на сервер.
post '/new' do

	#получаем данные из формы создания нового поста.
	@new_header = params[:new_header]
	@author_name = session[:identity]
	@new_post = params[:new_post]	
	
	#если имя автора или пост пусты, выдается ошибка 
	if @new_post =="" || @author_name=="" || @new_header ==""
		@error ='Заполните все поля формы, пожалуйста!'
		return erb :new
	end
	
	#если нет, пост добавляется в базу данных.
	@db.execute 'insert into 
				posts (Author_name, Header, Context, CreatedDate) 
				values (?, ?, ?, datetime())', [@author_name,@new_header,@new_post]
	
	#@number = @db.execute 'select id from posts order by posts.id desc limit 1'
	
	#после добавления поста в базу данных происходит перенаправление на главную страницу
	redirect to '/'
  
end

#здесь создается страничка для каждого поста с его номером в url
get '/details/:post_id' do
	
	post_id = params[:post_id]
	outpost = @db.execute 'select * from posts where id =?',[post_id]
	
	#эта переменная получает из базы все данные на кокретный пост, так как post_id у нас уникален
	#в представлении details.erb из этой переменной будем получать номер поста, сам текст и дату создания
	@row = outpost[0]
	
	#добавляем в переменную @comments все комментарии к конкретному посту по post_id
	@comments = @db.execute 'select * from comments where post_id = ? order by id',[post_id]
	
	erb :details
	
end

#здесь добавляются комментарии к публикациям

post '/details/:post_id' do	

		
		
		#форма запрашивает имя того, кто пишет комментарий
		#и непосредственно сам комментарий
		post_id = params[:post_id]
		@user_name = params[:user_name]
		@new_post = params[:new_post]		
		
		#если имя отправителя или поле комментария пусты, то форма обнуляется
		#пустой комментарий не добавляется.
		#к сожалению, пока не получилось вывести ошибку из-за непонимания, как правильно написать вид в erb :
		if @new_post =="" || @user_name==""	
			redirect to ('/details/' + post_id) 	
		end
	
	@db.execute 'insert into 
				comments (user_name, Context, CreatedDate, post_id) 
				values (?, ?, datetime(),?)', [@user_name, @new_post, post_id]
	
	redirect to ('/details/' + post_id) 
end
