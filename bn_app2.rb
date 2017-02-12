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
				authors
				(
					id          		INTEGER PRIMARY KEY AUTOINCREMENT,
					Registration_date	DATE NOT NULL,
					Author_name 		TEXT NOT NULL,
					Login				TEXT NOT NULL,
					Password			TEXT NOT NULL
				)'
	@db.execute 'CREATE TABLE IF NOT EXISTS
				posts 
				(
					id          INTEGER PRIMARY KEY AUTOINCREMENT,
					CreatedDate DATE NOT NULL,
					Author_name TEXT NOT NULL,
					Header		TEXT NOT NULL,
					SubHeader	TEXT NOT NULL,
					Context     TEXT NOT NULL,
					Img			TEXT,
					Views       INTEGER,
					Author_id   INTEGER NOT NULL
				)'
	@db.execute 'CREATE TABLE IF NOT EXISTS
				comments
				(
					id          INTEGER PRIMARY KEY AUTOINCREMENT,
					CreatedDate DATE NOT NULL,
					user_name   TEXT NOT NULL,
					Context     TEXT NOT NULL,
					post_id 	INTEGER NOT NULL
				)'
end

helpers do
  def username
    session[:identity] ? 'Вы вошли, как ' + session[:identity] : 'Hello stranger'
  end
end

# before '/new' do
  # unless session[:identity]
    # session[:previous_url] = request.path
    # @error = 'Для добавления статей нужно авторизоваться!'
    # halt erb(:login_form)
  # end
# end

get '/' do
	
	init_db
	#добавляем в переменную все посты с аргументом desc для вывода их
	#на экран в обратном порядке, т.е. самые свежие посты будут наверху списка
	@outpost = @db.execute 'select * from posts order by id desc'
  
  erb :index5
end

get '/login/form' do
	erb :login_form  
end

get '/login/attempt' do
  redirect to '/'
end

#здесь происходит авторизация пользователей
post '/login/attempt' do

	#инициализируем базу данных
	init_db
	
	#берем логин и пароль из формы 
	@login = params[:username]
	@password = params[:user_password]
	
	#здесь происходит проверка введенных пар --- логин и пароль --- на соответствие тем,
	#которые были введены пользователем при регистрации.
	#из базы authors достаются все пары и .....
	@validation = @db.execute 'select * from authors'
	@validation.each do |validation|		
		#.... происходит сравнение. Если соответствие найдено, то .........
		if @login == validation['Login'] && @password == validation['Password']
			#...........
			#этой переменной присваивается имя авторизованного автора 
			session[:identity] = validation['Author_name']
			#этой переменной присваивается id авторизованного автора 
			session[:id] = validation['id'] 
			#переход в вид кабинета
			erb :cabinet
		end
		
	end
   
		@message = "Access denied"
		where_user_came_from = session[:previous_url] || '/'
		redirect to where_user_came_from
		  
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/registration' do
	erb :registration
end

post '/registration' do
		
	@author_name = params[:author_name]
	@author_login = params[:author_login]
	@author_password = params[:author_password]
	@author_password_confirm = params[:author_password_confirm]
	
	@uniq_login = @db.execute 'select * from authors'
	
	@uniq_login.each do |uniq_login|	
		if @author_login == uniq_login['Login'] 
			@error = 'Такой логин уже существует, выберите другой'
			return erb :registration
		end		
	end
	if @author_password != @author_password_confirm	
		@error = 'Пароли не совпадают. Повторите ввод.'
		return erb :registration
	end
	@db.execute 'insert into 
				authors (Author_name, Login, Password, Registration_date) 
				values (?, ?, ?, datetime())', [@author_name, @author_login, @author_password]
	
	erb "Регистрация завершена, #{@author_name}. Теперь Вы можете войти на сайт"
end

get '/cabinet/:current_post_author_id' do
	
	@current_post_author_id = params[:current_post_author_id]	
	erb :cabinet
end
#здесь создается страница под каждого автора по его id
#страница информационная для ознакомления с автором и его статьями
#
get '/account_info/:current_post_author_id' do
	
	@current_post_author_id = params[:current_post_author_id]
	@Author_for_info = @db.execute ' select * from authors where id=?',[@current_post_author_id]
	@row_Author_for_info = @Author_for_info[0]
	
	@get_current_author_posts = @db.execute 'select * from posts where Author_id = ? order by id desc',[@current_post_author_id]
	
	erb :account_info
end

#обработчик запроса get. браузер получает страницу с сервера
get '/new' do
  erb :new
end

#**************СОЗДАНИЕ НОВЫХ ПОСТОВ************************

#здесь добавляются и проверяются на заполнение НОВЫЕ посты.
#обработчик запроса post. браузер отправляет страницу на сервер.
post '/new' do

	#инициализируем БД, чтобы иметь доступ к данным и возможность записи в БД
	init_db
	
	#получаем данные из формы создания нового поста.
	@author_name = session[:identity]
	@new_header = params[:new_header]
	@new_img = params[:new_img]
	@new_subheader = params[:new_subheader]	
	@new_post = params[:new_post]		
	
	#если имя автора или пост пусты, выдается ошибка 
	if @new_post =="" || @new_header ==""
		@error ='Заполните все поля формы, пожалуйста!'
		return erb :new
	end
				
	#если нет, пост добавляется в базу данных.
	@db.execute 'insert into 
				posts (Author_name, Header, SubHeader, Context, Img, CreatedDate, Author_id) 
				values (?, ?, ?, ?, ?, datetime(), ?)', [@author_name, @new_header, @new_subheader, @new_post, @new_img, session['id']]
			
	#после добавления поста в базу данных происходит перенаправление на главную страницу
	redirect to '/'
  
end
#=================================================================


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
