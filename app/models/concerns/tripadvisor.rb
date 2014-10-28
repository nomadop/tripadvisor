module Tripadvisor
	Host = 'http://www.tripadvisor.com'
	QueryUrl = 'http://www.tripadvisor.com/TypeAheadJson'

	module Helper
		module ClassMethods
			def find_or_create uri
				const_get('Index')[uri] || new(uri)
			end
		end
		
		module InstanceMethods
			def url
				Tripadvisor::Host + uri
			end
		end
		
		def self.included(receiver)
			receiver.extend         ClassMethods
			receiver.send :include, InstanceMethods
			receiver.send :attr_accessor, :id, :name, :uri
			receiver.const_set('Index', {})
		end
	end

	class Hotel
		include Tripadvisor::Helper
		attr_accessor :info, :reviews

		def initialize uri
			@uri = uri
			@id, @name = uri.scan(/-d(\d+)-Reviews-(.*?)-/)[0]
			@info = {}
			@reviews = []
			Tripadvisor::Hotel::Index[uri] = self
		end

		def load_info
			response = Conn.proxy :get, url
			doc = Nokogiri::HTML(response.body)
			ll_reg = /center=(-?\d+\.-?\d+),(-?\d+\.-?\d+)/
			info[:name] = doc.css('h1#HEADING')[0].content.gsub(/\n/, '')
			info[:rating] = doc.css('.popularity_and_ranking .rating img')[0]['content'].to_f / 5.0 * 100 if doc.css('.popularity_and_ranking .rating img').any?
			info[:review_count] = doc.css('.popularity_and_ranking .rating a span')[0].content.to_i if doc.css('.popularity_and_ranking .rating a span').any?
			info[:star_rating] = doc.css('.star .rate img')[0]['alt'].split(' ').first.to_f if doc.css('.star .rate img')[0]
			info[:format_address] = doc.css('.format_address')[0].content.gsub(/\n/, '') if doc.css('.format_address')[0]
			if doc.to_s =~ ll_reg
				info[:lat], info[:lng] = doc.to_s.scan(ll_reg)[0].map(&:to_f)
			end
			if info[:rating]
				info[:traveler_rating] = {}
				info[:rating_summary] = {}
				doc.css('.composite .wrap').each do |wrap|
					info[:traveler_rating][wrap.css('.text')[0].content] = wrap.css('.compositeCount')[0].content.to_i
				end
				doc.css('#SUMMARYBOX li').each do |li|
					rating = li.css('.rate img')[0]['alt'].split(' ')
					score = rating[0].to_f
					total = rating[2].to_f
					info[:rating_summary][li.css('.name')[0].content] = score / total * 100
				end
			end
			info
		end
	end

	class City
		include Tripadvisor::Helper
		attr_accessor :hotels

		def initialize uri
			@uri = uri
			@id, @name = uri.scan(/-g(\d+)-(.*?)-/)[0]
			@hotels = []
			Tripadvisor::City::Index[uri] = self
		end

		def load_hotels
			hotel_uris = []
			3.times do |i|
				worker = WorkerQueue.new("Get hotels count of #{name} on cat #{i + 1}...", id.to_i + (i + 1) / 10.0) do
					doc = Tripadvisor::City.request_hotels(id, i + 1, 0)
					count = doc.css('.p13n_header_tab_wrap .sprite-tab-active .tab_count')[0].content.gsub(/[\(\),]/, '').to_i
				end
				WorkerQueue.run if WorkerQueue.ready?
				worker.join
				count = worker.value

				workers = []
				0.step(count, 30) do |o|
					break if o == count
					weight = (id.to_i + (i + 1) / 10.0 + 0.0001 * (o / 30 + 1)).round(4)
					workers << WorkerQueue.new("Get hotels of #{name} on cat #{i + 1}, page #{o / 30 + 1}...", weight) do
						doc = Tripadvisor::City.request_hotels(id, i + 1, o)
						raise 'Response Error' if doc.css('#ACCOM_OVERVIEW .listing').empty?
						doc.css('#ACCOM_OVERVIEW .listing').map do |hotel|
							hotel.css('.quality a:first')[0]['href']
						end
					end
				end
				WorkerQueue.run if WorkerQueue.ready?
				workers.each {|w| w.join}
				hotel_uris += workers.map(&:value).flatten[0...count]
				pp "*" * 100
				pp "count: #{count}, hotel_uris_size: #{hotel_uris.size}"
				pp "*" * 100
			end
			@hotels = hotel_uris.map{ |uri| Tripadvisor::City.find_or_create(uri) }
		end

		def load_all
			load_hotels
			workers = []
			hotels.each do |h|
				workers << WorkerQueue.new("Run load info at `#{h.name}`") do
					h.load_info
				end
			end
			WorkerQueue.run(30) if WorkerQueue.ready?
			workers.each {|w| w.join}
		end

		def request_hotels cat, offset
			Tripadvisor::City.request_hotels(id, cat, offset)
		end

		def self.request_hotels id, cat, offset
			response = Conn.proxy :post, 'http://www.tripadvisor.com/Hotels', {
				geo: id,
				gasl: id,
				cat: cat,
				o: "a#{offset}"
			}
			doc = Nokogiri::HTML(response.body)
		end
	end

	class Country
		include Tripadvisor::Helper
		attr_accessor :cities

		def initialize uri
			@uri = uri
			@id, @name = uri.scan(/-g(\d+)-(.*?)-/)[0]
			@cities = []
			Tripadvisor::Country::Index[uri] = self
		end

		def load_cities threads = 30
			response = Conn.proxy :get, url
			doc = Nokogiri::HTML(response.body)
			city_uris = doc.css('.geo_name a').map { |a| a['href'] }
			count = doc.css('.pgCount')[0].content.split(' ').last.gsub(/\,/, '').to_i
			workers = []
			20.step(count, 20) do |p|
				break if p == count
				workers << WorkerQueue.new("Get cities of #{name} on page #{p / 20 + 1}") do
					response = Conn.proxy :get, url.split('-').insert(2, "oa#{p}").join('-')
					doc = Nokogiri::HTML(response.body)
					doc.css('.geo_name a').map { |a| a['href'] }
				end
			end
			WorkerQueue.run(threads) if WorkerQueue.ready?
			workers.each {|w| w.join}
			city_uris += workers.map(&:value).flatten
			@cities = city_uris.map do |uri|
				Tripadvisor::City.find_or_create(uri)
			end
		end

		def load_all
			WorkerQueue.stop
			load_cities
			workers = []
			cities.each do |c|
				workers << WorkerQueue.new("Run load hotels at `#{c.name}`", c.id.to_i, 3) do
					c.load_hotels
				end
			end
			WorkerQueue.run(100) if WorkerQueue.ready?
			workers.each {|w| w.join}
			workers.clear
			hotels = cities.map(&:hotels).flatten.uniq
			hotels.each do |h|
				workers << WorkerQueue.new("Run load info at `#{h.name}`", h.id.to_i) do
					h.load_info
				end
			end
			WorkerQueue.run(100) if WorkerQueue.ready?
			workers.each {|w| w.join}
		end

		def self.query name
			params = {
				action: 'API',
				types: 'geo,dest',
				hglt: true,
				global: true,
				link_type: 'hotel',
				blenderPages: false,
				scoreThreshold: 0.2,
				startTime: Time.now.to_i * 1000,
				uiOrigin: 'PTPT-dest',
				query: name
			}

			response = Conn.proxy :post, Tripadvisor::QueryUrl, params
			result = JSON.parse(response.body)['results'][0]
			find_or_create(result['url'])
		end
	end
end