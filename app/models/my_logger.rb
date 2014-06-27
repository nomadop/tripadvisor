class MyLogger
	FILENAME = "log.txt"

	def self.log message, level = 'DEBUG'
		File.open(MyLogger::FILENAME, "a+") do |file|
			file.puts "[#{Time.now}] #{level}: #{message}"
		end
	end

end