class Task < ActiveRecord::Base
	before_create :check_job_type
	after_create { whenever_add; init_log_folder }
	after_destroy { whenever_remove; remove_log_folder }
	after_initialize :init_serialize

	serialize :options, Hash
	serialize :time_summary, Array

	STATUS = {
		ready: 0,
		running: 1
	}

	LOG_LEVEL = :info

	LOG_LEVELS = {
		debug: 0,
		info: 1,
		warning: 2,
		error: 3
	}

	APP_DIR = Dir.pwd

	def send_hotel_score_cache_to_senscape
		Hotel.post_hotel_score_caches_to_senscape(options)
	end

	def get_hotels
		reviews = options[:reviews] == 'true' ? true : false

		Hotel.update_or_create_hotels_from_asiatravel_by_country_code(options[:ccode])
		Hotel.update_or_create_hotels_by_country_name_from_tripadvisor(options[:cname], reviews, self)
	end

	def match_hotels
		Hotel.match_hotels_between_tripadvisor_and_asiatravel_by_country(options[:cname], options.merge(logger: self))
	end

	ACCEPTABLE_JOB_TYPES = Task.instance_methods(false).map(&:to_s)

	def log_folder
		Task::APP_DIR + "/log/tasks/#{self.id}"
	end

	def log log_file, *args, &block
		args << {} unless args.last.instance_of?(Hash)
		options = args.last
		options[:level] = :debug if options[:level] == nil

		if Task::LOG_LEVELS[options[:level]] >= Task::LOG_LEVELS[Task::LOG_LEVEL]
			if block_given?
				File.open(log_file, options[:reset] ? "w" : "a+", &block)
			else
				File.open(log_file, options[:reset] ? "w" : "a+") {|file| file.puts "[#{Time.now.strftime("%H:%M:%S")}] #{args[0]}"}
			end
		end
	end

	def error_log *args, &block
		log(log_folder + '/error.log', *args, &block)
	end

	def simi_log *args, &block
		log(log_folder + "/simi_#{Time.now.strftime("%y%m%d")}.log", *args, &block)
	end

	def tripadvisor_log *args, &block
		log(log_folder + "/tripadvisor_#{Time.now.strftime("%y%m%d")}.log", *args, &block)
	end

	def log_list
		Dir.chdir log_folder
		(Dir.entries('.') - ['..', '.']).sort.map {|fname| [fname, File.size(fname)]}
	ensure
		Dir.chdir Task::APP_DIR
	end

	def whenever_reset
		whenever_remove
		whenever_add
	end

	def arrange_time
		time_summary.blank? ? 0 : time_summary.sum * 1.0 / time_summary.size
	end

	def run
		if Task.busy?
			return false
		else
			self.update(status: Task::STATUS[:running]) 
		end

		begin
			s_time = Time.now.to_i
			send(job_type)
		rescue Exception => e
			error_log(level: :error) do |file|
				file.puts "[#{Time.now}] #{e.inspect}:"
				e.backtrace.each do |line|
					file.puts "    #{line}"
				end
			end
		ensure
			self.status = Task::STATUS[:ready]
			self.time_summary << Time.now.to_i - s_time
			self.save
		end
	end

	def self.busy?
		Task.pluck(&:status).inject(0){|res, s| res |= s} == 1
	end

	def self.job_types
		Task::ACCEPTABLE_JOB_TYPES
	end

	def self.run id
		task = Task.find(id)
		task.run
	end

	def clear_log_folder
		Dir.chdir "log/tasks/#{self.id}"
		system('rm -f ./*')
	ensure
		Dir.chdir Task::APP_DIR
	end

	private
		def init_log_folder
			Dir.chdir 'log'
			Dir.mkdir 'tasks' unless File.directory? 'tasks'
			Dir.chdir 'tasks'
			Dir.mkdir "#{self.id}"
		ensure
			Dir.chdir Task::APP_DIR
		end

		def remove_log_folder
			Dir.chdir 'log/tasks'
			system("rm -f #{self.id}/*")
			Dir.rmdir "#{self.id}"
		ensure
			Dir.chdir Task::APP_DIR
		end

		def whenever_add
			File.open(Task::APP_DIR + "/config/schedule.rb", "a+") do |file|
				file.puts ""
				file.puts "# cronjob for task #{self.id}: #{self.name}"
				file.puts "every #{self.every}, at: '#{self.at}' do"
				file.puts "\trunner 'Task.run(#{self.id})'"
				file.puts "end"
			end
			system('whenever -iw')
		end

		def whenever_remove
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
			Dir.chdir(Task::APP_DIR)
			system('whenever -iw')
		end

		def check_job_type
			self.status = Task::STATUS[:ready]
			Task.job_types.include?(self.job_type)
		end

		def init_serialize
			self.options ||= {}
			self.options = options.keys.inject({}) do |result, key|
				result[key.to_sym] = options[key]
				result
			end
			self.time_summary ||= []
		end
end
