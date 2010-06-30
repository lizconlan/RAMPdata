require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'sass'
require 'mongo'

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

  @other_photos = coll.find({ "author_id" => "#{@first['author_id']}", "photo_id" => { "$not" => /^#{@first['photo_id']}$/ } } )

  haml :index
end

get "/unflag/:photo_id" do
  do_auth()
  
  coll = MONGO_DB.collection("flags")
  
  coll.remove("photo_id" => "#{params[:photo_id]}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/admin"
  end
end

private
  def do_auth
    ip = @env["REMOTE_HOST"]
    ip = @env["REMOTE_ADDR"] unless ip
    ip = @env["HTTP_X_REAL_IP"] unless ip
    authorize!(ip)
  end