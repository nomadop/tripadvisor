class Conn
	
	def self.init url, *args
		args << {} unless args.last.instance_of?(Hash)
		options = args.last

		conn = Faraday.new(:url => url) do |builder|
			builder.request		:url_encoded
			builder.response	:logger
			builder.adapter		Faraday.default_adapter
			builder.options.timeout = options[:timeout] || 5           # open/read timeout in seconds
  		builder.options.open_timeout = options[:open_timeout] || 2
		end
		conn.headers['User-Agent'] = "Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.131 Safari/537.36"
		yield conn if block_given?
		return conn
	end

end