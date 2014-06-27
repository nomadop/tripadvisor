class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :broadcast

  def broadcast channel, data
  	message = { :channel => channel, :data => data }
  	conn = Faraday.new(:url => "http://localhost:9292") do |faraday|
		  faraday.request  :url_encoded             # form-encode POST params
		  faraday.response :logger                  # log requests to STDOUT
		  faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
		end
		conn.post '/faye', { :message => message.to_json }
  end
end
