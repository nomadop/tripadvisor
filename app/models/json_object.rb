class JSONObject	
	def initialize raw
		raw = JSON.parse(raw) unless raw.instance_of?(Hash)
		raw.each do |key, value|
			self.singleton_class.send(:attr_accessor, key)
			self.send("#{key}=", JSONObject.parse_value(value))
		end
	end

	def __attrs__
		self.instance_variables.map{|s| s[1..-1].to_sym}
	end

	def method_missing name
		nil
	end

	def self.parse_arr arr
		arr.map { |value|	JSONObject.parse_value(value) }
	end

	def self.parse_value value
		case value
		when Hash
			JSONObject.new(value)
		when Array
			JSONObject.parse_arr(value)
		else
			value										
		end
	end

end