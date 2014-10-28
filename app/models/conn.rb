class Conn
	class Proxy
		attr_accessor :url, :process, :max, :total, :total_response_time, :busy_time

		def initialize url, max
			@url = url
			@process = 0
			@max = max
			@total = 0
			@total_response_time = 0
			@busy_time = 0
			@mutex = Mutex.new
		end

		def connect
			@mutex.synchronize do
				@process += 1
				@busy_at = Time.now.to_f if process == max
			end
		end

		def disconnect response_time
			@mutex.synchronize do
				@busy_time += Time.now.to_f - @busy_at if process == max
				@process -= 1
				@total += 1
				@total_response_time += response_time
			end
		end

		def avg_response_time
			total_response_time / total
		end
	end
	# Proxys = [Proxy.new("http://localhost:4567/", 10),
	# 					Proxy.new("http://182.92.233.59", 10),
	# 					Proxy.new("http://182.92.235.199:4567", 10),
	# 					Proxy.new("http://182.92.235.158:4567", 10),
	# 					Proxy.new("http://203.195.155.91:8080/", 5)]
	Proxys = YAML.load(File.read('proxys.yml')).map do |proxy|
		Proxy.new(proxy[:url], proxy[:max])
	end
	ProxyMutex = Mutex.new

	def self.get_proxy
		Proxys.select{|x| x.max - x.process > 0}.shuffle.first
	end
	
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

	def self.proxy method, url, data = {}
		st = Time.now.to_f
		p = nil
		res = nil
		begin
			while p == nil
				p = get_proxy
				if p
					p.connect
				else
					sleep 1
				end
			end
			conn = Faraday.new(p.url) do |builder|
				builder.request		:url_encoded
				builder.response	:logger
				builder.adapter		Faraday.default_adapter
				builder.options.timeout = 5           # open/read timeout in seconds
	  		builder.options.open_timeout = 2
			end
			res = conn.post('/', {
				url: url,
				method: method,
				data: data
			})
			status = 'success'
		rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
			status = 'retry'
		rescue Exception => e
			p e
			p e.backtrace
			status = 'error'
			error = e
		end
		File.open('conn.log', 'a+') {|io| io.puts "[#{Time.now.strftime("%H:%M:%S")}] #{p.url}: #{status}"}
		p.disconnect(Time.now.to_f - st)
		case status
		when 'success'
			res
		when 'retry'
			proxy(method, url, data)
		when 'error'
			raise e
		end
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