module WorkerQueue
	Array.class_eval do
		def bininsert ele, order = :asc
			base = 2 ** (self.size.to_s(2).size - 1)
			index = 0
			cmp = order == :asc ? :> : :<
			while base > 0 && index < self.size
				# pp [index, base]
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

		def self.test
			synchronize do
				@@queue
			end
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
				while synchronize{ @@queue.select{|w| w.alive?}.size } > 30 && @@status == 1
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