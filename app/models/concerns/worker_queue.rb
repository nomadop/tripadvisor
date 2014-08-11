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
		attr_accessor :block, :weight, :status, :value, :thread, :timeout

		def initialize weight, timeout, &block
			@block = block
			@weight = weight
			@timeout = timeout
			@status = 'ready'
		end

		def run
			return false unless self.ready?
			@status = 'alive'
			@thread = Thread.new do
				value = @block.call(@weight)
				@status = 'dead'
				@value = value
				WorkerQueue.synchronize do
					WorkerQueue.delete(self)
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

	module_function
		@@status = 0
		@@queue = []
		@@mutex = Mutex.new
		@@concurrency = 30

		def self.queue
			@@queue
		end

		def self.concurrency
			@@concurrency
		end

		def self.concurrency= concurrency
			@@concurrency = concurrency
		end

		def self.new weight, timeout, &block
			worker = Worker.new(weight, timeout, &block)
			synchronize do
				@@queue.bininsert(worker){ |e| e.weight }
			end
			worker
		end

		def self.delete worker
			@@queue.delete(worker)
		end

		def self.clear
			@@queue.clear
		end

		def self.synchronize &block
			raise 'No block given' unless block_given?
			@@mutex.synchronize do
				yield
			end
		end

		def self.run
			return false if @@status == 1
			@@status = 1
			while synchronize{ @@queue.select{|w| w.ready?}.size } > 0 && @@status == 1
				while synchronize{ @@queue.select{|w| w.alive?}.size } > @@concurrency && @@status == 1
					sleep 10
				end
				w = @@queue.select{|w| w.ready?}[0]
				w.run
				sleep w.timeout
			end
			@@status = 0
		end

		def self.stop
			@@status = 0
			synchronize do
				@@queue.each { |w| w.kill }
				clear
			end
		end
end