class Hotel < ActiveRecord::Base
	after_initialize :init_location

	validates_uniqueness_of :name
	validates_presence_of :name

	serialize :location, Hash
	serialize :traveler_rating, Hash
	serialize :rating_summary, Hash
	has_many :reviews

	def self.get_hotel_infos_from_tripadvisor
		100000.times do |dnum|
			begin
				hotel_info = TripadvisorCrawler.get_hotel_info_by_dnum(100000+dnum)
				Hotel.create(hotel_info) if hotel_info != nil
			rescue Exception => e
				p e
			end
		end
	end

	def self.init_hotels_by_city_name_from_tripadvisor city_name
		hotel_infos = TripadvisorCrawler.get_hotel_infos_by_city_name(city_name)
		Hotel.create(hotel_infos)
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
