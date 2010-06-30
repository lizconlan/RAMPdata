require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'sass'
require 'mongo'
require 'helpers/auth'

enable :sessions

def self.get_mongo_connection
  if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
    db_name = ENV['MONGO_DB']
    db_server = ENV['MONGO_SERVER']
    db_port = ENV['MONGO_PORT']
    db_user = ENV['MONGO_USER']
    db_pass = ENV['MONGO_PASS']
  else    
    mongo_conf = YAML.load(File.read('config/virtualserver/mongo.yml'))
    db_name = mongo_conf[:db]
    db_server = mongo_conf[:server]
    db_port = mongo_conf[:port]
    db_user = mongo_conf[:user]
    db_pass = mongo_conf[:pass]
  end

  db = Mongo::Connection.new(db_server, db_port).db(db_name)
  db.authenticate(db_user, db_pass)
  
  return db
end

MONGO_DB = get_mongo_connection()

get '/' do
  coll = MONGO_DB.collection("flags")
  photos = coll.find()
  @first = photos.next_document
  
  @mp_name = format_name_for_url(@first['name'])

  @other_photos = coll.find({ "author_id" => "#{@first['author_id']}", "photo_id" => { "$not" => /^#{@first['photo_id']}$/ } } )

  haml :index
end

get "/unflag/:photo_id" do
  #do_auth()
  
  coll = MONGO_DB.collection("flags")
  
  coll.remove("photo_id" => "#{params[:photo_id]}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/"
  end
end

get "/stop_mp_photo/:mp_name/:photo_id" do
  #do_auth()
  
  coll = MONGO_DB.collection("stoplist")
  
  mp_name = mp_name_from_querystring(params[:mp_name])
  
  photo_id =  params[:photo_id]
  
  #get the flag values to move across
  coll = MONGO_DB.collection("flags")
  photo = coll.find("photo_id" => "#{photo_id}", "name" => "#{mp_name}").next_document()
  
  if photo
    #add a new document to the stoplist
    coll = MONGO_DB.collection("stoplist")
    new_photo_doc = {"photo_id" => "#{photo_id}", "name" => "#{mp_name}", "flickr_secret" => "#{photo["flickr_secret"]}", "flickr_farm" => "#{photo["flickr_farm"]}", "flickr_server" => "#{photo["flickr_server"]}", "author_id" => "#{photo["author_id"]}"}
    coll.insert(new_photo_doc)
  end
  
  #remove the "old" document from the flags collection
  coll = MONGO_DB.collection("flags")
  coll.remove("photo_id" => "#{photo_id}", "name" => "#{mp_name}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/"
  end
end

get "/stop_photo/:photo_id" do
  #do_auth()
  
  photo_id =  params[:photo_id]
  
  #get the flag values to move across
  coll = MONGO_DB.collection("flags")
  photo = coll.find("photo_id" => "#{photo_id}").next_document()
  
  if photo
  #add a new document to the stoplist
    coll = MONGO_DB.collection("stoplist")
    new_photo_doc = {"photo_id" => "#{photo_id}", "flickr_secret" => "#{photo["flickr_secret"]}", "flickr_farm" => "#{photo["flickr_farm"]}", "flickr_server" => "#{photo["flickr_server"]}", "author_id" => "#{photo["author_id"]}"}
    coll.insert(new_photo_doc)
  end
  
  #remove the "old" document from the flags collection
  coll = MONGO_DB.collection("flags")
  coll.remove("photo_id" => "#{photo_id}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/"
  end
end

private
  def do_auth
    ip = @env["REMOTE_HOST"]
    ip = @env["REMOTE_ADDR"] unless ip
    ip = @env["HTTP_X_REAL_IP"] unless ip
    authorize!(ip)
  end
  
  def mp_name_from_querystring(param_name)
    name = param_name.gsub("-", " ")
    name.gsub!("  ", "-")

    names = []
    parts = name.split(" ")
    parts.each do |part|
      names << part.capitalize
    end
    
    name = names.join(" ")
    
    if name =~ /\ Mc([a-z])/
      name = name.gsub("Mc#{$1}", "Mc#{$1.upcase()}")
    end
    
    if name =~ /\ Mac([a-z])/
      name = name.gsub("Mac#{$1}", "Mac#{$1.upcase()}")
    end
    
    name
  end

  def format_name_for_url(name)
    name.downcase().gsub("-","--").gsub(" ","-")
  end