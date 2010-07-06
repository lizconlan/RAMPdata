require 'sinatra/base'

module Sinatra 
  module SessionAuth

    module Helpers
      def authorized?
        session[:authorized]
      end

      def authorize!(ip_address)
        @is_admin = true
        unless authorized?
          if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
            user = ENV['ADMIN_USER']
            pass = ENV['ADMIN_PASS']
            ips = ENV['ADMIN_IPS']
          else
            admin_conf = YAML.load(File.read('config/virtualserver/admin.yml'))
            user = admin_conf[:user]
            pass = admin_conf[:pass]
            ips = admin_conf[:allowed_ips]
          end

          raise ip_address
          
          if ip_address && ips.split("|").include?(ip_address)
            session[:authorized] = true
          else
            redirect '/login'
          end
        end
      end

      def logout!
        session[:authorized] = false
      end
    end

    def self.registered(app)
      app.helpers SessionAuth::Helpers      
    
      if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
        ips = ENV['ADMIN_IPS']
      else
        admin_conf = YAML.load(File.read('config/virtualserver/admin.yml'))
        ips = admin_conf[:allowed_ips]
      end
    end
  end

  register SessionAuth
  helpers Sinatra::SessionAuth
end