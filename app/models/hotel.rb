# encoding: utf-8

class Hotel < ActiveRecord::Base
	after_initialize :init_location

	serialize :location, Hash
	serialize :traveler_rating, Hash
	serialize :rating_summary, Hash
	has_many :reviews

	def self.kuhn_munkres hotelsA, hotelsB, simi_table = nil
		s = []
		t = []
		l1 = []
		l2 = []
		inf = 1000000000
		simi_table ||= get_similarity_table(hotelsA, hotelsB)
		m_table = (0...hotelsA.size).map {|i| hotelsA[i].id}
		m = m_table.size
		n_table = (0...hotelsB.size).map {|i| hotelsB[i].id}
		n = n_table.size
		m_n_table = m_table.map do |m|
			n_table.map { |n| simi_table[m][n] }
		end
		for i in (0...m) do
			l1[i] = -inf
			for j in (0...n) do
				l1[i] = m_n_table[i][j] > l1[i] ? m_n_table[i][j] : l1[i]
			end
			return -1 if l1[i] == -inf
		end
		for i in (0...n) do
			l2[i] = 0
		end
		match1 = match2 = []
		n.times { |i| match1[i] = match2[i] = -1 }
		for i in (0...m) do
			t = []
			n.times { |j| t[j] = -1 }
			p = 0
			q = 0
			s[0] = i
			while p <= q && match1[i] < 0
				k = s[p]
				puts "#{p}: k=#{k}" if i == 109
				for j in (0...n) do
					puts "j=#{j}: s=#{s}, l1[k]=#{l1[k]}, l2[j]=#{l2[j]}, mnt[k,j]=#{m_n_table[k][j]}, t[j]=#{t[j]}" if i == 109
					break unless match1[i] < 0
					if l1[k] + l2[j] == m_n_table[k][j] && t[j] < 0
						q += 1
						s[q] = match2[j]
						t[j] = k
						puts "q=#{q}, s[q]=#{s[q]}, t[j]=#{t[j]}, match2" if i == 109
						if s[q] < 0
							p = j
							while p >= 0
								match2[j] = k = t[j]
								p = match1[k]
								match1[k] = j
								j = p
								puts "p=#{p}, k=#{k}, j=#{j}" if i == 109 || k == 281
							end
						end
					end
				end
				p += 1
			end
			if match1[i] < 0
				i -= 1
				p = inf
				for k in (0..q) do
					for j in (0...n) do
						p = l1[s[k]] + l2[j] - m_n_table[s[k]][j] if l1[s[k]] + l2[j] - m_n_table[s[k]][j] < p
					end
				end
				for j in (0...n) do
					l2[j] += t[j] < 0 ? 0 : p
				end
				for k in (0..q) do
					l1[s[k]] -= p
				end
			end
		end
		match1
	end

	def self.get_similarity_table hotelsA, hotelsB
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
			puts "the most hotel similar to (#{hotelA.name}) is (#{most_simi_hotel.name}), similarity is #{max_simi}"
			puts "    #{hotelA.name}: #{hotelA.format_address}"
			puts "    #{most_simi_hotel.name}: #{most_simi_hotel.format_address}"
			puts '=' * 100
			simi_table.map do |x|
				x == nil ? [] : x.map { |y| y == nil ? 0 : y }
			end
		end
	end

	def self.similarity hotelA, hotelB
		similarity = 0
		num_regexp = /\b(\d+)\b/
		a_nums = hotelA.format_address.scan(num_regexp).map { |a| a[0] }
		b_nums = hotelB.format_address.scan(num_regexp).map { |a| a[0] }
		a_nums.each do |an|
			b_nums.each do |bn|
				similarity += 0.1 * an.to_s.size if an == bn
			end
		end
		similarity += levenshtein(hotelA.name, hotelB.name) * 0.7
		similarity += levenshtein(hotelA.format_address, hotelB.format_address) * 0.3
		#puts "similarity between (#{hotelA.name}) and (#{hotelB.name}) is #{similarity}"
		return similarity
	end

	def self.street_number address
			if address =~ /\b\d+\-\d+\b/
				num, s, e = /\b(\d+)\-(\d+)\b/.match(address).to_a
				(s..e).map{|x| x}
			else
				m = /\b(\d+[A-E]?)\b/.match(address)
				m[1] if m
			end
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
				up_left = domic[i - 1][j - 1] + ( c1 == c2 ? 0.0 : weight )
				domic[i][j] = [left, up, up_left].min
			end
		end
		1.0 - (domic[str1.size][str2.size] / [str1.size, str2.size].max.to_f)
	end

	def self.create_hotel_by_hotel_info_from_asiatravel hotel_info
		regex = /([\u4e00-\u9fa5]*)/
		name = regex.match(hotel_info['name'].gsub(/\w|\d/, ''))[1].blank? ? hotel_info['name'] : Youdao.translate(hotel_info['name'])
		name = /\((.*)\)$/.match(name)[1] if name =~ /\((.*)\)$/
		Hotel.create(
			name: regex.match(hotel_info['name'].gsub(/\w|\d/, ''))[1].blank? ? hotel_info['name'] : Youdao.translate(hotel_info['name']),
			star_rating: hotel_info['star_rating_name'].to_f,
			location: { 'City' => hotel_info['city_name'] },
			format_address: regex.match(hotel_info['address'].gsub(/\w|\d/, ''))[1].blank? ? hotel_info['address'] : nil,
			street_address: regex.match(hotel_info['address'].gsub(/\w|\d/, ''))[1].blank? ? nil : Youdao.translate(hotel_info['address']),
			tag: 'asiatravel'
			)
	end

	def self.get_hotel_infos_from_asiatravel city_name = nil
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

	def self.init_hotels_from_tripadvisor
		100000.times do |dnum|
			begin
				hotel_info = TripadvisorCrawler.get_hotel_info_by_dnum(100000+dnum)
				hotel_info[:reviews] = Review.create(hotel_info[:reviews])
				Hotel.create(hotel_info) if hotel_info != nil
			rescue Exception => e
				p e
			end
		end
	end

	def self.init_hotels_by_city_name_from_tripadvisor city_name
		hotel_infos = TripadvisorCrawler.get_hotel_infos_by_city_name(city_name)
		hotel_infos.each do |hotel_info|
			hotel_info[:reviews] = Review.create(hotel_info[:reviews])
		end
		Hotel.create(hotel_infos)
	end

	def self.update_hotels_by_city_name_from_tripadvisor city_name, load_reviews
		hotel_infos = TripadvisorCrawler.get_hotel_infos_by_city_name(city_name, load_reviews)
		hotel_infos.each do |hotel_info|
			hotel = Hotel.find_by(name: hotel_info[:name])
			hotel.update(hotel_info) if hotel
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
		def init_location
			self.location ||= {}
			self.traveler_rating ||= {}
			self.rating_summary ||= {}
		end
end
