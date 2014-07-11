# encoding: utf-8

class Hotel < ActiveRecord::Base
	before_create :validates_unique
	after_initialize :init_location

	serialize :location, Hash
	serialize :traveler_rating, Hash
	serialize :rating_summary, Hash
	scope :city, ->(city_name){ where("location like ?", "%#{city_name}%") }
	has_many :reviews, dependent: :destroy

	def self.post_hotel_score_cache_to_senscape hotel, conn
		response = conn.get '/hotel_score_caches/new'
		conn.headers['cookie'] = response.headers['set-cookie']
		doc = Nokogiri::HTML(response.body)
		authenticity_token = doc.css("[name='authenticity_token']")[0]['value']
		matched_hotel = Hotel.find(hotel.hotel_id)
		response = conn.post '/hotel_score_caches', {
			'authenticity_token' => authenticity_token,
			'hotel_score_cache[hotel_code]' => hotel.source_id,
			'hotel_score_cache[hotel_name]' => hotel.name,
			'hotel_score_cache[rating]' => matched_hotel.rating,
			'hotel_score_cache[review_count]' => matched_hotel.review_count,
			'hotel_score_cache[traveler_rating]' => matched_hotel.traveler_rating,
			'hotel_score_cache[rating_summary]' => matched_hotel.rating_summary
		}		
	rescue Faraday::TimeoutError => e
		post_hotel_score_cache_to_senscape(hotel, conn)
	end

	def self.post_hotel_score_caches_to_senscape
		conn = Conn.init('http://asia.senscape.com.cn')
		response = conn.get '/users/login'
		conn.headers['cookie'] = response.headers['set-cookie']
		doc = Nokogiri::HTML(response.body)
		authenticity_token = doc.css("[name='authenticity_token']")[0]['value']
		response = conn.post '/users/check_password', {
			utf8: '✓',
			authenticity_token: authenticity_token,
			email: 'nomadop@gmail.com',
			pwd: '366534743'
		}
		conn.headers['cookie'] = response.headers['set-cookie']
		Hotel.where(tag: 'asiatravel').where.not(hotel_id: nil).each do |hotel|
			post_hotel_score_cache_to_senscape(hotel, conn)
		end
	end

	def address
		self.format_address.blank? ? self.street_address : self.format_address
	end

	def match_hotels_from_other_tag hotels, *args
		simi_table = hotels.inject([]) do |table, hotel|
			if args[0] && args[0][:no_dist] == false
				simi = Hotel.similarity(self, hotel, false)
			else
				simi = Hotel.similarity(self, hotel)
			end
			i = 0
			for i in (0..table.size) do
				break if table[i] && table[i][1] < simi
			end
			table.insert(i, [hotel, simi])
		end
		self.hotel_id = simi_table[0][0].id
		self.save
		return simi_table[0]
		# File.open("similarity.log", "a+") do |file|
		# 	file.puts "the most hotel similar to (#{self.name}) is (#{simi_table[0][0].name}), similarity is #{simi_table[0][1]}"
		# 	file.puts "    #{self.name}: #{self.format_address.blank? ? self.street_address : self.format_address}"
		# 	file.puts "    #{simi_table[0][0].name}: #{self.format_address.blank? ? simi_table[0][0].street_address : simi_table[0][0].format_address}"
		# 	file.puts "    distance is #{GeocodingApi.get_distance(self.location['lat'].to_f, self.location['lng'].to_f, simi_table[0][0].location['latlng'][0]['lat'], simi_table[0][0].location['latlng'][0]['lng'])}"
		# 	file.puts '=' * 100
		# end
	end

	def self.match_hotels_between_tripadvisor_and_asiatravel_by_country country_name, *args
		hotels_from_asiatravel = Hotel.where(tag: 'asiatravel').city(country_name)
		citys = hotels_from_asiatravel.map{ |hotel| hotel.location['City'] }.uniq
		citys.each { |city| match_hotels_between_tripadvisor_and_asiatravel_by_city(city, *args) }
	end

	def self.match_hotels_between_tripadvisor_and_asiatravel_by_city city_name, *args
		hotelsA = Hotel.where(tag: 'asiatravel').city(city_name)
		hotelsB = Hotel.where(tag: 'tripadvisor').city(city_name)
		# File.open("similarity.log", "w") { |file| file.puts "start:" }
		hotelsA.each do |hotelA|
			result = hotelA.match_hotels_from_other_tag(hotelsB, *args)
			matched_hotel = result[0]
			similarity = result[1]
			File.open("similarity.log", "a+") do |file|
				file.puts "the most hotel similar to (#{hotelA.name}) is (#{matched_hotel.name}), similarity is #{similarity}"
				file.puts "    #{hotelA.name}: #{hotelA.format_address.blank? ? hotelA.street_address : hotelA.format_address}"
				file.puts "    #{matched_hotel.name}: #{hotelA.format_address.blank? ? matched_hotel.street_address : matched_hotel.format_address}"
				file.puts "    distance is #{GeocodingApi.get_distance(hotelA.location['lat'].to_f, hotelA.location['lng'].to_f, matched_hotel.location['latlng'][0]['lat'], matched_hotel.location['latlng'][0]['lng'])}"
				file.puts '=' * 100
			end
		end
		# self.kuhn_munkres(hotelsA, hotelsB)
		true
	end

	def get_similarity_table_of hotels
		hotels.map do |h|
			[h.name, Hotel.similarity(self, h), h.format_address]
		end
	end

	def self.get_similarity_table_of hotel, hotels
		hotel = Hotel.find_by(name: hotel) if hotel.instance_of? String
		hotel.get_similarity_table_of(hotels)
	end

	def self.kuhn_munkres hotelsA, hotelsB, simi_table = nil
		raise "M must be smaller than N" if hotelsA.size > hotelsB.size
		s = []
		t = []
		l1 = []
		l2 = []
		inf = 1000000000
		simi_table ||= get_similarity_table(hotelsA, hotelsB)
		m_table = hotelsA.map(&:id)
		m = m_table.size
		n_table = hotelsB.map(&:id)
		n = n_table.size
		m_n_table = m_table.map do |m|
			n_table.map { |n| (simi_table[m][n] * 100).round(0) }
		end
		for i in (0...m) do
			l1[i] = -inf
			for j in (0...n) do
				l1[i] = m_n_table[i][j] > l1[i] ? m_n_table[i][j] : l1[i]
			end
			return false if l1[i] == -inf
		end
		for i in (0...n) do
			l2[i] = 0
		end
		match1 = []
		match2 = []
		m.times { |i| match1[i] = -1 }
		n.times { |i| match2[i] = -1 }
		i = 0
		while i < m
			t = []
			n.times { |j| t[j] = -1 }
			p = 0
			q = 0
			s[0] = i
			while p <= q && match1[i] < 0
				k = s[p]
				# puts "#{p}: k=#{k}" if i == 109
				j = 0
				while j < n
					# puts "j=#{j}: s=#{s}, l1[k]=#{l1[k]}, l2[j]=#{l2[j]}, mnt[k,j]=#{m_n_table[k][j]}, t[j]=#{t[j]}" if i == 109
					break unless match1[i] < 0
					if l1[k] + l2[j] == m_n_table[k][j] && t[j] < 0
						q += 1
						s[q] = match2[j]
						t[j] = k
						# puts "q=#{q}, s[q]=#{s[q]}, t[j]=#{t[j]}, m2[j]=#{match2[j]}" if i == 109
						if s[q] < 0
							p = j
							while p >= 0
								match2[j] = k = t[j]
								p = match1[k]
								match1[k] = j
								# puts "p=#{p}, k=#{k}, j=#{j}" if i == 109 || match2[j] == 281
								j = p
							end
						end
					end
					j += 1
				end
				p += 1
			end
			if match1[i] < 0
				i -= 1
				p = inf
				for k in (0..q) do
					for j in (0...n) do
						p = l1[s[k]] + l2[j] - m_n_table[s[k]][j] if t[j] < 0 && l1[s[k]] + l2[j] - m_n_table[s[k]][j] < p
					end
				end
				for j in (0...n) do
					l2[j] += t[j] < 0 ? 0 : p
				end
				for k in (0..q) do
					l1[s[k]] -= p
				end
		  	File.open("km_result.txt", "a+") { |file| file.puts "i=#{i}, p=#{p}" }
			end
			i += 1
		end
		#return match1
		File.open('km_result.txt', 'w') do |file|
			match1.each_with_index do |n, m|
				if n >= 0
					hotelA = Hotel.find(m_table[m])
					hotelB = Hotel.find(n_table[n])
					file.puts "Hotel(#{hotelA.name}) match hotel(#{hotelB.name}), similarity is #{simi_table[m_table[m]][n_table[n]]}"
					file.puts "    Hotel(#{hotelA.name}): #{hotelA.format_address.blank? ? hotelA.street_address : hotelA.format_address}"
					file.puts "    Hotel(#{hotelB.name}): #{hotelA.format_address.blank? ? hotelB.street_address : hotelB.format_address}"
					# hotelA.matched_hotel = hotelB
					# hotelB.matched_hotel = hotelA
				else
					file.puts "Can not find match of hotel(#{hotelA.name})"
				end
				file.puts "=" * 100
			end
		end
	end

	def self.get_similarity_table hotelsA, hotelsB
		File.open("similarity.log", "w") { |file| file.puts "start:" }
		hotelsA.inject([]) do |simi_table, hotelA|
			max_simi = 0
			most_simi_hotel = nil
			simi_table[hotelA.id] = hotelsB.inject([]) do |ha_table, hotelB|
				ha_table[hotelB.id] = similarity(hotelA, hotelB)
				simi_table[hotelB.id] ||= []
				simi_table[hotelB.id][hotelA.id] = ha_table[hotelB.id]
				if ha_table[hotelB.id] > max_simi
					max_simi = ha_table[hotelB.id]
					most_simi_hotel = hotelB
				end
				ha_table
			end
			File.open("similarity.log", "a+") do |file|
				file.puts "the most hotel similar to (#{hotelA.name}) is (#{most_simi_hotel.name}), similarity is #{max_simi}"
				file.puts "    #{hotelA.name}: #{hotelA.format_address.blank? ? hotelA.street_address : hotelA.format_address}"
				file.puts "    #{most_simi_hotel.name}: #{hotelA.format_address.blank? ? most_simi_hotel.street_address : most_simi_hotel.format_address}"
				file.puts "    distance is #{GeocodingApi.get_distance(hotelA.location['lat'].to_f, hotelA.location['lng'].to_f, most_simi_hotel.location['latlng'][0]['lat'], most_simi_hotel.location['latlng'][0]['lng'])}"
				file.puts '=' * 100
			end
			simi_table.map do |x|
				x == nil ? [] : x.map { |y| y == nil ? 0 : y }
			end
		end
	end

	def self.similarity hotelA, hotelB, with_distance = true
		similarity = 0
		num_regexp = /\b(\d+[\-\d+]?*)\b/
		if hotelA.format_address.blank?
			a_nums = hotelA.street_address.scan(num_regexp).map { |a| a[0] }
			b_nums = hotelB.street_address.scan(num_regexp).map { |a| a[0] }
		else
			a_nums = hotelA.format_address.scan(num_regexp).map { |a| a[0] }
			b_nums = hotelB.format_address.scan(num_regexp).map { |a| a[0] }
		end
		a_nums.each do |an|
			b_nums.each do |bn|
				similarity += 0.1 * an.to_s.size if an == bn
			end
		end
		similarity += levenshtein(hotelA.name, hotelB.name) * 0.7
		if hotelA.format_address.blank?
			similarity += levenshtein(hotelA.street_address, hotelB.street_address) * 0.3
		else
			similarity += levenshtein(hotelA.format_address, hotelB.format_address) * 0.3
		end
		if with_distance == true
			if hotelB.location['latlng']
				latlngs = hotelB.location['latlng']
			else
				latlngs = GeocodingApi.get_latlng({street: hotelB.street_address, city: hotelB.location['City'], country: hotelB.location['Country']})
				hotelB.location['latlng'] = latlngs
				hotelB.save
			end
			distances = latlngs.map do |latlng|
				GeocodingApi.get_distance(hotelA.location['lat'].to_f, hotelA.location['lng'].to_f, latlng['lat'].to_f, latlng['lng'].to_f)
			end
			# puts "min_distance between (#{hotelA.name}) and (#{hotelB.name}) is #{distances.min}"
			case distances.min
			when 0...100
				similarity += 1
			when 100...300
				similarity += 0.7
			when 300...500
				similarity += 0.5
			when 500...1000
				similarity += 0.3
			end
		end
		#puts "similarity between (#{hotelA.name}) and (#{hotelB.name}) is #{similarity}"
		return similarity
	end

	def self.levenshtein str1, str2, weight = 1.0
		domic = str1.chars.map{[]}
		domic << []
		domic[0][0] = 0.0
		str2.size.times do |i|
			domic[0][i + 1] = (i + 1.0).to_f
		end
		str1.chars.each_with_index do |c1, i|
			i += 1
			domic[i][0] = i.to_f
			str2.chars.each_with_index do |c2, j|
				j += 1
				left = domic[i][j - 1] + 1.0
				up = domic[i - 1][j] + 1.0
				up_left = domic[i - 1][j - 1] + ( c1.downcase == c2.downcase ? 0.0 : weight )
				domic[i][j] = [left, up, up_left].min
			end
		end
		1.0 - (domic[str1.size][str2.size] / [str1.size, str2.size].max.to_f)
	end

	def self.create_hotel_by_hotel_info_from_asiatravel hotel_info
		regex = /([\u4e00-\u9fa5]*)/
		name = ''
		in_quotes = /[\（|\(](.*)[\）|\)]/.match(hotel_info['hotel_name'])
		in_quotes = in_quotes[1] if in_quotes
		if !in_quotes.blank?
			if in_quotes.scan(regex).select{|a| !a[0].blank?}.empty?
				name = in_quotes
			else
				name = Youdao.translate(in_quotes)
			end
		else
			name = hotel_info['hotel_name']
			name = name.gsub(/\w|\d|\ /, '').scan(regex).select{|a| !a[0].blank?}.empty? ? name : Youdao.translate(name)
		end
		source_id = hotel_info['hotel_code']
		hotel = Hotel.where(tag: 'asiatravel', source_id: source_id)[0]
		if hotel
			hotel.update(
				name: name,
				# star_rating: hotel_info['star_rating_name'].to_f,
				location: { 
					'Country' => hotel_info['country_name'],
					'City' => hotel_info['city_name'],
					'latlng' => [{
						'lat' => hotel_info['latitude'],
						'lng' => hotel_info['longitude']
						}],
					'lat' => hotel_info['latitude'],
					'lng' => hotel_info['longitude']
					},
				format_address: regex.match(hotel_info['hotel_address'].gsub(/\w|\d/, ''))[1].blank? ? hotel_info['hotel_address'] : nil,
				street_address: regex.match(hotel_info['hotel_address'].gsub(/\w|\d/, ''))[1].blank? ? nil : Youdao.translate(hotel_info['hotel_address']),
				tag: 'asiatravel'
				)
		else
			Hotel.create(
				source_id: source_id,
				name: name,
				# star_rating: hotel_info['star_rating_name'].to_f,
				location: { 
					'Country' => hotel_info['country_name'],
					'City' => hotel_info['city_name'],
					'latlng' => [{
						'lat' => hotel_info['latitude'],
						'lng' => hotel_info['longitude']
						}],
					'lat' => hotel_info['latitude'],
					'lng' => hotel_info['longitude']
					},
				format_address: regex.match(hotel_info['hotel_address'].gsub(/\w|\d/, ''))[1].blank? ? hotel_info['hotel_address'] : nil,
				street_address: regex.match(hotel_info['hotel_address'].gsub(/\w|\d/, ''))[1].blank? ? nil : Youdao.translate(hotel_info['hotel_address']),
				tag: 'asiatravel'
				)
		end
	end

	def self.init_hotels_from_asiatravel city_name = nil
		conn = Conn.init('http://asia.senscape.com.cn')
		response = conn.get '/users/login'
		conn.headers['cookie'] = response.headers['set-cookie']
		doc = Nokogiri::HTML(response.body)
		authenticity_token = doc.css("[name='authenticity_token']")[0]['value']
		response = conn.post '/users/check_password', {
			utf8: '✓',
			authenticity_token: authenticity_token,
			email: 'nomadop@gmail.com',
			pwd: '366534743'
		}
		conn.headers['cookie'] = response.headers['set-cookie']
		conn.params['city'] = city_name if city_name
		response = conn.get '/hotels.json'
		hotel_infos = JSON.parse(response.body)
		hotel_infos.map do |hotel_info|
			create_hotel_by_hotel_info_from_asiatravel(hotel_info)
		end
	end

	def self.update_or_create_hotels_from_asiatravel_by_country_code_and_city_code country_code, city_code, ingore_ids = []
		conn = Conn.init('http://localhost:3000', timeout: 1.day.to_i)
		response = conn.get '/users/login'
		conn.headers['cookie'] = response.headers['set-cookie']
		doc = Nokogiri::HTML(response.body)
		authenticity_token = doc.css("[name='authenticity_token']")[0]['value']
		response = conn.post '/users/check_password', {
			utf8: '✓',
			authenticity_token: authenticity_token,
			# email: 'nomadop@gmail.com',
			# pwd: '366534743'
			email: '123@123.123',
			pwd: '123456'
		}
		conn.headers['cookie'] = response.headers['set-cookie']
		conn.params['country_code'] = country_code
		conn.params['city_code'] = city_code
		conn.params['ignids'] = ingore_ids.join(',')
		response = conn.get '/hotel_score_caches/get_hotel_infos_from_asiatravel_by_country_code_and_city_code.json'
		hotel_infos = JSON.parse(response.body)
		hotel_infos.map do |hotel_info|
			create_hotel_by_hotel_info_from_asiatravel(hotel_info)
		end
	end

	def self.update_or_create_hotels_from_asiatravel_by_country_code country_code, ingore_ids = []
		conn = Conn.init('http://localhost:3000', timeout: 1.day.to_i)
		response = conn.get '/users/login'
		conn.headers['cookie'] = response.headers['set-cookie']
		doc = Nokogiri::HTML(response.body)
		authenticity_token = doc.css("[name='authenticity_token']")[0]['value']
		response = conn.post '/users/check_password', {
			utf8: '✓',
			authenticity_token: authenticity_token,
			# email: 'nomadop@gmail.com',
			# pwd: '366534743'
			email: '123@123.123',
			pwd: '123456'
		}
		conn.headers['cookie'] = response.headers['set-cookie']
		conn.params['country_code'] = country_code
		conn.params['ignids'] = ingore_ids.join(',')
		response = conn.get '/hotel_score_caches/get_hotel_infos_from_asiatravel_by_country_code.json'
		hotel_infos = JSON.parse(response.body)
		hotel_infos.map do |hotel_info|
			create_hotel_by_hotel_info_from_asiatravel(hotel_info)
		end
	end

	def self.update_or_create_hotel_by_hotel_info_from_tripadvisor hotel_info
		hotel = Hotel.where(tag: hotel_info[:tag], source_id: hotel_info[:source_id])[0]
		hotel_info[:reviews] = Review.update_or_create(hotel_info[:reviews]) if hotel_info[:reviews]
		if hotel
			hotel.update(hotel_info)
		else
			Hotel.create(hotel_info)
		end
	end

	def self.update_or_create_hotels_by_city_name_from_tripadvisor city_name, load_reviews
		File.open("log.txt", "w") { |file| file.puts "start mission: update_or_create_hotels_by_city_name_from_tripadvisor(#{city_name}, load_reviews)" }
		hotel_infos = TripadvisorCrawler.get_hotel_infos_by_city_name(city_name, load_reviews)
		hotel_infos.each do |hotel_info|
			update_or_create_hotel_by_hotel_info_from_tripadvisor(hotel_info)
		end
	end

	def self.update_or_create_hotels_by_country_name_from_tripadvisor country_name, load_reviews
		File.open("log.txt", "w") { |file| file.puts "start mission: update_or_create_hotels_by_country_name_from_tripadvisor(#{country_name}, load_reviews)" }
		city_urls = TripadvisorCrawler.get_city_urls_by_country_name(country_name)
		city_urls.each do |city_url|
			hotel_infos = TripadvisorCrawler.get_hotel_infos_by_geourl(city_url, load_reviews)
			hotel_infos.each { |hotel_info| update_or_create_hotel_by_hotel_info_from_tripadvisor(hotel_info) }
		end
	end

	def street_number
		if self.street_address
			address = self.street_address
			if address =~ /\b\d+\-\d+\b/
				num, s, e = /\b(\d+) ?\- ?(\d+)\b/.match(address).to_a
				(s.to_i..e.to_i).map{|x| x}
			else
				m = /\b(\d+[A-E]?)\b/.match(address)
				m[1] if m
			end
		end
	end

	def comment_count
		self.reviews.count
	end

	private
		def validates_unique
			Hotel.where(tag: self.tag, source_id: self.source_id).empty?
		end

		def init_location
			self.location ||= {}
			self.traveler_rating ||= {}
			self.rating_summary ||= {}
		end
end
