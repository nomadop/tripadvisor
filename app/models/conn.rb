class Conn
	
	def self.init url, *args
		args << {} unless args.last.instance_of?(Hash)
		options = args.last

		conn_options = options.reject { |key, val| [:adapter, :timeout, :open_timeout].include?(key) }

		conn = Faraday.new(url, conn_options) do |builder|
			builder.request		:url_encoded
			builder.response	:logger
			builder.adapter		options[:adapter] || Faraday.default_adapter
			builder.options.timeout = options[:timeout] || 5           # open/read timeout in seconds
  		builder.options.open_timeout = options[:open_timeout] || 2
		end
		conn.headers['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"
		yield conn if block_given?
		return conn
	end

	Faraday::Connection.class_eval do
		def try method, *args, &block
			raise 'No such method' unless [:post, :get].include?(method)
			send(method, *args, &block)
		rescue Faraday::TimeoutError => e
			try(method, *args, &block)
		rescue Faraday::ConnectionFailed => e
			try(method, *args, &block)
		end
	end

end