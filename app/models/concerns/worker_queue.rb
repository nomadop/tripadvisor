module WorkerQueue
	# 增加数组对象的二分插排方法
	Array.class_eval do
		# 二分插排
		#   ele: 待插入元素
		#   order: 递增:asc, 递减:desc
		#   block: *可选* 比较依据
		def bininsert ele, order = :asc
			# 取一个正好不大于自身大小的2^x
			base = 2 ** (self.size.to_s(2).size - 1)
			index = 0
			cmp = case order
			when :asc, 'asc'
				:>
			when :desc, 'desc'
				:<
			else
				raise 'No such order'
			end

			while base > 0 && index < self.size
				while self[index + base] == nil || (block_given? ? yield(self[index + base]).send(cmp, yield(ele)) : self[index + base].send(cmp, ele))
					break if base == 0
					base >>= 1
				end
				index += base
			end
			index += 1 if self[index] && (block_given? ? yield(ele).send(cmp, yield(self[index])) : ele.send(cmp, self[index]))
			
			self.insert(index, ele)
		end
	end

	class Worker
		attr_accessor :name, :block, :weight, :status, :value, :thread, :timeout, :retry

		def initialize name, weight, timeout, &block
			@name = name
			@block = block
			@weight = weight
			@timeout = timeout
			@retry = 0
			@status = 'ready'
			# WorkerQueue::Logger.log "Work(#{weight}) `#{name}` initialized..."
		end

		def run
			return false unless self.ready?
			#WorkerQueue::Logger.log "Work(#{weight}) `#{name}` start#{" (retry: #{@retry})" if @retry > 0}..."
			@status = 'alive'
			@thread = Thread.new do
				begin
					value = @block.call(@weight)
					@value = value
					WorkerQueue::Logger.log "Work(#{weight}) `#{name}` succeed..."
					@status = 'dead'
					WorkerQueue.synchronize do
						WorkerQueue.delete(self)
						WorkerQueue.complete(self)
					end
				rescue Exception => e
					@value = e
					WorkerQueue::Logger.log "Work(#{weight}) `#{name}` failed: #{e.inspect}..."
					e.backtrace.each do |t|
						WorkerQueue::Logger.log "    #{t}"
					end
					@retry += 1
					if @retry > 3 
						@status = 'dead'
						WorkerQueue.synchronize do
							WorkerQueue.delete(self)
							WorkerQueue.fail(self)
						end
					else
						@status = 'ready'
					end
				end
			end
			true
		end

		def kill
			@thread.kill if @thread.respond_to? :kill
			@status = 'dead'
		end

		def join
			while self.ready?
				sleep 10
			end
			@thread.join
		end

		def alive?
			@status == 'alive'
		end

		def ready?
			@status == 'ready'
		end
	end

	# class Queue
	# 	attr_accessor :status, :queue, :mutex, :concurrency

	# 	def initialize concurrency = 30
	# 		@status = 0
	# 		@queue = []
	# 		@mutex = Mutex.new
	# 		@concurrency = concurrency
	# 	end

	# 	def ready?
	# 		status == 0
	# 	end

	# 	def running?
	# 		status == 1
	# 	end

	# 	def new weight = 0, timeout = 0.1, &block
	# 		worker = WorkerQueue::Worker.new(weight, timeout, &block)
	# 		synchronize do
	# 			queue.bininsert(worker){ |e| e.weight }
	# 		end
	# 		worker
	# 	end

	# 	def synchronize &block
	# 		raise 'No block given' unless block_given?
	# 		mutex.synchronize do
	# 			yield
	# 		end
	# 	end

	# 	def delete worker
	# 		queue.delete(worker)
	# 	end

	# 	def clear
	# 		queue.clear
	# 	end

	# 	def self.run async = true
	# 		return false if @status == 1
	# 		@status = 1
	# 		while synchronize{ queue.select{|w| w.ready?}.size } > 0 && status == 1
	# 			while synchronize{ queue.select{|w| w.alive?}.size } > concurrency && status == 1
	# 				sleep 10
	# 			end
	# 			w = queue.select{|w| w.ready?}[0]
	# 			w.run
	# 			sleep w.timeout
	# 		end
	# 		@@queue.each { |w| w.join } if async != true
	# 		@status = 0
	# 		true
	# 	end

	# 	def self.results
	# 		@@queue.map(&:value)
	# 	end

	# 	def self.stop
	# 		@@status = 0
	# 		synchronize do
	# 			@@queue.each { |w| w.kill }
	# 			clear
	# 		end
	# 	end
	# end

	class Logger
		Mut = Mutex.new
		FilePath = "/log/worker_queue.log"

		def self.log message
			Mut.synchronize do
				File.open(Dir.pwd + FilePath, "a+") {|file| file.puts "[#{Time.now.strftime("%H:%M:%S")}] #{message} (#{WorkerQueue.queue.size})"}
			end
			message
		end

		def self.clear
			Mut.synchronize do
				File.open(Dir.pwd + FilePath, "w") {|file| file.puts ""}
			end
		end
	end

	module_function
		@@status = 0
		@@locked = false
		@@queue = []
		@@completed = []
		@@failed = []
		@@mutex = Mutex.new
		@@concurrency = 100

		def self.ready?
			@@status == 0 && @@queue.size > 0
		end

		def self.running?
			@@status == 1
		end

		def self.lock
			@@locked = true
		end

		def self.unlock
			@@locked = false
		end

		def self.queue
			@@queue
		end

		def self.completed
			@@completed
		end

		def self.failed
			@@failed
		end

		def self.concurrency
			@@concurrency
		end

		def self.concurrency= concurrency
			@@concurrency = concurrency
		end

		def self.new name, weight = 0, timeout = 0.1, &block
			worker = Worker.new(name, weight, timeout, &block)
			synchronize do
				@@queue.bininsert(worker){ |e| e.weight }
			end
			worker
		end

		def self.delete worker
			@@queue.delete(worker)
			@@status = 0 if @@queue.size == 0
		end

		def self.clear
			@@queue.clear
			WorkerQueue::Logger.clear
		end

		def self.complete worker
			@@completed << worker
		end

		def self.fail worker
			@@failed << worker
		end

		def self.synchronize &block
			raise 'No block given' unless block_given?
			@@mutex.synchronize do
				yield
			end
		end

		def self.run concurrency = @@concurrency
			return false if running?
			@@status = 1
			while @@queue.size > 0
				while synchronize{ @@queue.select{|w| w.alive?}.size } > concurrency && @@status == 1
					sleep 3
				end
				w = @@queue.select{|w| w.ready?}[0]
				if w
					w.run
					sleep w.timeout
				else
					sleep 3
				end
			end
		end

		def self.results
			@@completed.map(&:value)
		end

		def self.stop
			@@status = 0
			synchronize do
				@@queue.each { |w| w.kill }
				clear
			end
		end
end