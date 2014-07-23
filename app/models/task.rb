class Task < ActiveRecord::Base
	before_create :check_job_type
	after_create :whenever_add
	after_destroy :whenever_remove
	after_update { whenever_remove; whenever_add }
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
		Hotel.update_or_create_hotels_by_country_name_from_tripadvisor(cname, true)
		Hotel.match_hotels_between_tripadvisor_and_asiatravel_by_country(cname)
		self.update(status: Task::STATUS[:ready])
	end

	def self.job_types
		Task.instance_methods(false).map(&:to_s)
	end

	def self.run id
		task = Task.find(id)
		task.send(task.job_type)
	end

	private
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
		end
end
