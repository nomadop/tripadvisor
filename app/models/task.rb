class Task < ActiveRecord::Base
	before_create :check_job_type
	after_create { whenever_add; init_log_folder }
	after_destroy { whenever_remove; remove_log_folder }
	after_initialize :init_serialize

	serialize :options, Hash

	STATUS = {
		start_up: -1,
		ready: 0,
		running: 1
	}

	def get_and_match_hotels
		unless status == Task::STATUS[:running]
			self.update(status: Task::STATUS[:running]) 
		else
			return false
		end
		cname = options[:cname]
		ccode = options[:ccode]
		Hotel.update_or_create_hotels_from_asiatravel_by_country_code(ccode)
		Hotel.update_or_create_hotels_by_country_name_from_tripadvisor(cname, true, self)
		Hotel.match_hotels_between_tripadvisor_and_asiatravel_by_country(cname, logger: self)
		self.update(status: Task::STATUS[:ready])
	end

	ACCEPTABLE_JOB_TYPES = Task.instance_methods(false).map(&:to_s)

	def simi_log *args, &block
		if block_given?
			File.open(Dir.pwd + "/log/tasks/#{self.id}/#{Time.now.strftime("%y%m%d")}_simi.log", args[0] && args[0][:reset] ? "w" : "a+", &block)
		else
			File.open(Dir.pwd + "/log/tasks/#{self.id}/#{Time.now.strftime("%y%m%d")}_simi.log", args[1] && args[1][:reset] ? "w" : "a+") {|file| file.puts args[0]}
		end
	end

	def tripadvisor_log *args, &block
		if block_given?
			File.open(Dir.pwd + "/log/tasks/#{self.id}/#{Time.now.strftime("%y%m%d")}_tripadvisor.log", args[0] && args[0][:reset] ? "w" : "a+", &block)
		else
			File.open(Dir.pwd + "/log/tasks/#{self.id}/#{Time.now.strftime("%y%m%d")}_tripadvisor.log", args[1] && args[1][:reset] ? "w" : "a+") {|file| file.puts args[0]}
		end
	end

	def whenever_reset
		whenever_remove
		whenever_add
	end

	def self.job_types
		Task::ACCEPTABLE_JOB_TYPES
	end

	def self.run id
		task = Task.find(id)
		task.send(task.job_type)
	end

	private
		def init_log_folder
			app_dir = Dir.pwd
			Dir.chdir 'log'
			Dir.mkdir 'tasks' unless File.directory? 'tasks'
			Dir.chdir 'tasks'
			Dir.mkdir "#{self.id}"
		ensure
			Dir.chdir app_dir
		end

		def remove_log_folder
			app_dir = Dir.pwd
			Dir.chdir 'log/tasks'
			system("rm -f #{self.id}/*")
			Dir.rmdir "#{self.id}"
		ensure
			Dir.chdir app_dir
		end

		def whenever_add
			File.open(Dir.pwd + "/config/schedule.rb", "a+") do |file|
				file.puts ""
				file.puts "# cronjob for task #{self.id}: #{self.name}"
				file.puts "every #{self.every}, at: '#{self.at}' do"
				file.puts "\trunner 'Task.run(#{self.id})'"
				file.puts "end"
			end
			system('whenever -iw')
		end

		def whenever_remove
			app_dir = Dir.pwd
			Dir.chdir('config')
			%x[mv schedule.rb schedule.rb.old]
			output = File.open("schedule.rb", "w")
			skip = 0
			File.foreach("schedule.rb.old") do |line|
				skip = 5 if line.include?("# cronjob for task #{self.id}:")
				if skip > 0
					skip -= 1
				else
					output.puts line
				end
			end
		ensure
			output.close
			%x[rm schedule.rb.old]
			Dir.chdir(app_dir)
			system('whenever -iw')
		end

		def check_job_type
			self.status = Task::STATUS[:start_up]
			Task.job_types.include?(self.job_type)
		end

		def init_serialize
			self.options ||= {}
			self.options = options.keys.inject({}) do |result, key|
				result[key.to_sym] = options[key]
				result
			end
		end
end
