# encoding: utf-8

class TripadvisorCrawler
	URL = 'http://www.tripadvisor.com'
	HOTEL_REVIEW_URL = '/Hotel_Review-d%dnum.html'
	QUERY_URL = '/TypeAheadJson'
	
	def self.get_hotel_infos_by_country_name country_name, load_reviews, logger = Hotel, ignore_citys = []
		city_urls = TripadvisorCrawler.get_city_urls_by_country_name(country_name, ignore_list: ignore_citys, logger: logger)
		WorkerQueue.clear
		workers = []
		city_urls.each_with_index do |city_url, index|
			workers << WorkerQueue.new(index, 1) do
				TripadvisorCrawler.get_all_infos_by_geourl(city_url, index, 0.1, load_reviews: load_reviews, logger: logger, only_url: true)
			end
		end
		WorkerQueue.run
		workers.each { |w| w.join }
		hotel_urls = workers.inject([]) do |arr, w|
			arr += w.value
		end
		hotel_ids = []
		hotel_urls.select! do |url|
			hid = /d(\d+)/.match(url)[1].to_i
			if hotel_ids.include?(hid)
				false
			else
				hotel_ids << hid
				true
			end
		end
		logger.tripadvisor_log "Got #{hotel_urls.size} hotels:", level: :info
		WorkerQueue.clear
		workers.clear
		hotel_urls.each_with_index do |url, index|
			workers << WorkerQueue.new(index, 0.1) do
				TripadvisorCrawler.get_hotel_info_by_hotelurl(url, load_reviews: load_reviews, logger: logger, task_number: index)
			end
		end
		WorkerQueue.run
		workers.each { |w| w.join }
		workers.map(&:value).compact
	end

	def self.get_conn
		conn = Faraday.new(:url => TripadvisorCrawler::URL) do |builder|
			builder.request		:url_encoded
			builder.response	:logger
			builder.adapter		Faraday.default_adapter
			builder.options.timeout = 5           # open/read timeout in seconds
  		builder.options.open_timeout = 2
		end
		conn.headers['User-Agent'] = "Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.131 Safari/537.36"
		return conn
	end

	def self.get_hotel_reviews_by_hotelurl url, conn, logger
		response = conn.get(url)
		doc = Nokogiri::HTML(response.body)
		review_ids = doc.css('.reviewSelector').map { |x| x['id'][7..-1].to_i }
		conn.params = {
			target: review_ids[0],
			context: 0,
			reviews: review_ids.join(','),
			servlet: 'Hotel_Review',
			expand: 1
		}
		response = conn.post "/ExpandedUserReviews-#{url.match(/g\d+/)[0]}-#{url.match(/d\d+/)[0]}", {
			gac: 'Reviews',
			gaa: 'expand',
			gass: 'Hotel_Review',
			gasl: url.match(/d\d+/)[0][1..-1].to_i
		}
		doc = Nokogiri::HTML(response.body)
		cn_reg = /([\u4e00-\u9fa5]*)/
		hira_reg = /([ぁ-ん]*)/
		reviews = doc.css('.extended').inject([]) do |result, r|
			begin
				unless r.css('.entry')[0].content.scan(cn_reg).delete_if{|x| x[0].blank?}.empty?
					if r.css('.entry')[0].content.scan(hira_reg).delete_if{|x| x[0].blank?}.empty?
						result << {
							review_id: r['id'][2..-1].to_i,
							title: r.css(".innerBubble a")[0].content[1...-1],
							content: r.css('.entry')[0].content.gsub(/\n/, '')
						}
					end
				end
			rescue Exception => e
				p e
				logger.tripadvisor_log "Got review failed at #{url}! Error: #{e.inspect}", level: :error
			end
			result
		end
	rescue Faraday::TimeoutError => e
		logger.tripadvisor_log "Timeout when Got hotel_reviews from #{url.split('/').last}, retry:", level: :warning
		get_hotel_reviews_by_hotelurl(url, conn, logger)
	rescue Faraday::ConnectionFailed => e
		logger.tripadvisor_log "Timeout when Got hotel_reviews from #{url.split('/').last}, retry:", level: :warning
		get_hotel_reviews_by_hotelurl(url, conn, logger)
	rescue Exception => e
		logger.tripadvisor_log(level: :error) do |file|
			file.puts "#{e.inspect}:"
			e.backtrace.each do |line|
				file.puts "    #{line}"
			end
		end
		return []
	end

	def self.get_hotel_info_by_hotelurl url, options = {}
		default_opts = {lang: 'zhCN'}
		options = default_opts.merge(options)

		options[:logger].tripadvisor_log "Task#{options[:task_number] ? "(#{options[:task_number]})" : ""} get: #{url.split('/').last}", level: :info

		begin
			conn = get_conn
			if options[:load_reviews] == true
				response = conn.post '/SetLangFilter', {
					returnTo: '__2F__' + url.split('/').last.gsub(/_/, '__5F__').gsub(/-/, '__2D__').gsub(/\./, '__2E__'),
					filterLang: options[:lang]
				}
				url = response.headers['location']
				conn.headers['cookie'] = response.headers['set-cookie']
			end
			response = conn.get url
			return nil unless response.status == 200
			doc = Nokogiri::HTML(response.body)
			ll_reg = /center=(-?\d+\.-?\d+),(-?\d+\.-?\d+)/
			hotel_info = {}
			hotel_info[:source_id] = /d(\d+)/.match(url)[1].to_i
			hotel_info[:name] = doc.css('h1#HEADING')[0].content.gsub(/\n/, '')
			hotel_info[:rating] = doc.css('.userRating .rating img')[0]['content'].to_f / 5.0 * 100 if doc.css('.userRating .rating img').any?
			hotel_info[:review_count] = doc.css('.userRating .rating a span')[0].content.to_i if doc.css('.userRating .rating a span').any?
			hotel_info[:location] = {}
			hotel_info[:traveler_rating] = {}
			hotel_info[:rating_summary] = {}
			hotel_info[:reviews] = [] if options[:load_reviews] == true
			doc.css('.breadcrumbs a').each do |link|
				place = link['onclick'].split(', ')[2].gsub(/'/, '')
				unless place.blank?
					hotel_info[:location][place] ||= link.content
				end
			end
			hotel_info[:star_rating] = doc.css('.star .rate img')[0]['alt'].split(' ').first.to_f if doc.css('.star .rate img')[0]
			hotel_info[:format_address] = doc.css('.format_address')[0].content.gsub(/\n/, '') if doc.css('.format_address')[0]
			hotel_info[:street_address] = doc.css('.format_address .street-address')[0].content if doc.css('.format_address .street-address')[0]
			if doc.to_s =~ ll_reg
				coord = doc.to_s.scan(ll_reg)[0]
				latlng = [{'lat' => coord[0].to_f, 'lng' => coord[1].to_f}]
			else
				latlng = []
			end
			hotel_info[:location]['latlng'] = latlng
			hotel_info[:tag] = 'tripadvisor'
			if hotel_info[:rating]
				doc.css('.composite .wrap').each do |wrap|
					hotel_info[:traveler_rating][wrap.css('.text')[0].content] = wrap.css('.compositeCount')[0].content.to_i
				end
				doc.css('#SUMMARYBOX li').each do |li|
					rating = li.css('.rate img')[0]['alt'].split(' ')
					score = rating[0].to_f
					total = rating[2].to_f
					hotel_info[:rating_summary][li.css('.name')[0].content] = score / total * 100
				end
			end
			if options[:load_reviews] == true
				if doc.css('.pgCount')[0]
					count = doc.css('.pgCount')[0].content.split(' ')[2].to_i
				else
					count = 9
				end
				0.step(count, 10) do |p|
					break if p == count
					hotel_paginated_url = p == 0 ? url : url.split('-').insert(4, "or#{p}").join('-')
					reviews = get_hotel_reviews_by_hotelurl(hotel_paginated_url, conn, options[:logger]).compact
					if reviews.any?
						hotel_info[:reviews] += reviews
					else
						break
					end
					conn.params = {}
				end
			end
			options[:logger].tripadvisor_log "Task#{options[:task_number] ? "(#{options[:task_number]})" : ""} finish: get_hotel_info_by_hotelurl(#{url.split('/').last})"
			return hotel_info
		rescue Faraday::TimeoutError => e
			options[:logger].tripadvisor_log "Task#{options[:task_number] ? "(#{options[:task_number]})" : ""} WARNING: Timeout when Got hotel_info from #{url.split('/').last}, retry:", level: :warning
			get_hotel_info_by_hotelurl(url, options)
		rescue Faraday::ConnectionFailed => e
			options[:logger].tripadvisor_log "Task#{options[:task_number] ? "(#{options[:task_number]})" : ""} WARNING: Timeout when Got hotel_info from #{url.split('/').last}, retry:", level: :warning
			get_hotel_info_by_hotelurl(url, options)
		rescue Exception => e
			options[:logger].tripadvisor_log(level: :error) do |file|
				file.puts "#{e.inspect}:"
				e.backtrace.each do |line|
					file.puts "    #{line}"
				end
			end
			return nil
		end
	end

	def self.get_hotel_info_by_dnum dnum
		conn = get_conn
		response = conn.get TripadvisorCrawler::HOTEL_REVIEW_URL.gsub(/%dnum/, dnum.to_s)
		return nil unless response.status == 301
		location = response.headers['location']
		return nil unless location.split('/').last[0...5] == 'Hotel'
		get_hotel_info_by_hotelurl(location)
	end

	def self.get_hotel_infos_by_geourl url, options = {}
		default_opts = {load_reviews: true}
		options = default_opts.merge(options)

		options[:logger].tripadvisor_log "Task start: get_hotel_infos_by_geourl(#{url.split('/').last})", level: :info if options[:logger]

		# puts options
		# File.open("log.txt", "a+") { |io| io.puts options.inspect }

		conn = get_conn
		response = conn.get url
		doc = Nokogiri::HTML(response.body)
    hotel_urls = []
		hotel_infos = []
		begin
			count = doc.css("#INLINE_COUNT i")[0].content.to_i
		rescue Exception => e
			count = 0
		end
		doc.css('#ACCOM_OVERVIEW .listing').each do |hotel|
			hotel_urls << TripadvisorCrawler::URL + hotel.css('.quality a:first')[0]['href']
		end
		if options[:only_count] == true
			return count
		end
		options[:logger].tripadvisor_log "    got #{count} hotels", level: :info
		30.step(count, 30) do |p|
			break if p == count
			flag = 'pending'
			while flag == 'pending'
				begin
					response = conn.get url.split('-').insert(url.split('-').size - 2, "oa#{p}").join('-')
					flag = 'current'
				rescue Faraday::TimeoutError => e
					flag = 'pending'
				rescue Exception => e
					raise e
				end
			end
			doc = Nokogiri::HTML(response.body)
			doc.css('#ACCOM_OVERVIEW .listing').each do |hotel|
				hotel_urls << TripadvisorCrawler::URL + hotel.css('.quality a:first')[0]['href']
			end
		end
		hotel_urls = hotel_urls[0...count]
		hotel_urls.each { |url| options[:logger].tripadvisor_log "    #{url}" }
		if options[:only_id] == true
			return hotel_urls.map { |url| /d(\d+)/.match(url)[1].to_i }
		end
		if options[:only_url] == true
			return hotel_urls
		end
		workers = []
		hotel_urls.each_with_index do |url, index|
			weight = "#{options[:weight]}#{"%04d" % (index + 1)}".to_f
			workers << WorkerQueue.new(weight, 0.1) do |wid|
				TripadvisorCrawler.get_hotel_info_by_hotelurl(url, options.merge({task_number: wid}))
			end
		end
		workers.each { |w| w.join }
		hotel_infos = workers.map(&:value).compact
	rescue Faraday::TimeoutError => e
		options[:logger].tripadvisor_log "Timeout when Got hotel_infos from #{url.split('/').last}, retry:", level: :warning
		get_hotel_infos_by_geourl(url, options)
	rescue Faraday::ConnectionFailed => e
		options[:logger].tripadvisor_log "Timeout when Got hotel_infos from #{url.split('/').last}, retry:", level: :warning
		get_hotel_infos_by_geourl(url, options)
	rescue Exception => e
		options[:logger].tripadvisor_log(level: :error) do |file|
			file.puts "#{e.inspect}:"
			e.backtrace.each do |line|
				file.puts "    #{line}"
			end
		end
		return []
	end

	def self.get_all_infos_by_geourl url, weight, timeout, options = {}
		# get_hotel_infos_by_geourl(url, options) +
		# get_hotel_infos_by_geourl(url.split('-').insert(2, "c2").join('-'), options) +
		# get_hotel_infos_by_geourl(url.split('-').insert(2, "c3").join('-'), options)
		w1 = WorkerQueue.new(weight + 0.1, timeout){ TripadvisorCrawler.get_hotel_infos_by_geourl(url, options.merge({weight: weight + 0.1})) }
		w2 = WorkerQueue.new(weight + 0.2, timeout){ TripadvisorCrawler.get_hotel_infos_by_geourl(url.split('-').insert(2, "c2").join('-'), options.merge({weight: weight + 0.2})) }
		w3 = WorkerQueue.new(weight + 0.3, timeout){ TripadvisorCrawler.get_hotel_infos_by_geourl(url.split('-').insert(2, "c3").join('-'), options.merge({weight: weight + 0.3})) }
		w1.join
		w2.join
		w3.join
		w1.value + w2.value + w3.value
	end

	def self.get_hotel_infos_by_gnum gnum
		
	end

	def self.get_hotel_infos_by_city_name city_name, options = {}
		default_opts = {load_reviews: true}
		options = default_opts.merge(options)

		options[:logger].tripadvisor_log "Task start: get_hotel_infos_by_city_name(#{city_name})", level: :info

		query = {
			action: 'API',
			types: 'geo,hotel',
			hglt: true,
			global: true,
			link_type: 'hotel',
			blenderPages: false,
			scoreThreshold: 0.2,
			filter: 'nobroad',
			startTime: Time.now.to_i * 1000,
			uiOrigin: 'PTPT-hotel',
			query: city_name
		}

		conn = get_conn
		response = conn.post TripadvisorCrawler::QUERY_URL, query
		result = JSON.parse(response.body)['results'].select{|r| r['title'] == 'Destinations'}[0]
		if result
			get_all_infos_by_geourl(result['url'], options)
		else
			[]
		end
	end

	def self.get_hotel_count_by_country_name country_name
		city_urls = get_city_urls_by_country_name(country_name)
		city_urls.inject(0) do |count, city_url|
			count += get_all_infos_by_geourl(city_url, load_reviews: false, only_count: true)
		end
	end

	def self.get_hotel_ids_by_country_name country_name
		city_urls = get_city_urls_by_country_name(country_name)
		city_urls.inject([]) do |ids, city_url|
			ids += get_all_infos_by_geourl(city_url, load_reviews: false, only_id: true)
		end
	end

	def self.get_city_urls_by_country_name country_name, options = {}
		default_opts = {ignore_list: []}
		options = default_opts.merge(options)

		options[:logger].tripadvisor_log "Task start: get_city_urls_by_country_name(#{country_name})", level: :info

		query = {
			action: 'API',
			types: 'geo,dest',
			hglt: true,
			global: true,
			link_type: 'hotel',
			blenderPages: false,
			scoreThreshold: 0.2,
			startTime: Time.now.to_i * 1000,
			uiOrigin: 'PTPT-dest',
			query: country_name
		}

		conn = get_conn
		response = conn.post TripadvisorCrawler::QUERY_URL, query
		result = JSON.parse(response.body)['results'][0]
		url = result['url']
		response = conn.get(url)
		doc = Nokogiri::HTML(response.body)
		city_urls = doc.css('.geo_name a').map { |a| a['href'] unless options[:ignore_list].include?(a.content[0...-7]) }
		count = doc.css('.pgCount')[0].content.split(' ').last.gsub(/\,/, '').to_i
		20.step(count, 20) do |p|
			break if p == count
			flag = 'pending'
			while flag == 'pending'
				begin
					response = conn.get url.split('-').insert(2, "oa#{p}").join('-')
					flag = 'current'
				rescue Faraday::TimeoutError => e
					flag = 'pending'
				rescue Exception => e
					raise e
				end
			end
			doc = Nokogiri::HTML(response.body)
			city_urls += doc.css('.geo_name a').map { |a| a['href'] unless options[:ignore_list].include?(a.content[0...-7]) }
		end
		city_urls.delete(nil)
		options[:logger].tripadvisor_log "    got #{city_urls.count} citys", level: :info
		city_urls
	rescue Faraday::TimeoutError => e
		get_city_urls_by_country_name(country_name, options)
	end

end