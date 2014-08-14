class HotelsSimilarityTable < ActiveRecord::Base
	before_create :check_validates

	def self.find_or_create_by *args
		case args.size
		when 1
			super(args[0])
		when 2
			hotelA = args[0]
			hotelB = args[1]
			super(hotela_code: hotelA.id, hotela_tag: hotelA.tag, hotelb_code: hotelB.id, hotelb_tag: hotelB.tag)
		end
	end

	def self.create *args
		case args.size
		when 1
			super(args[0])
		when 2
			hotelA = args[0]
			hotelB = args[1]
			super(hotela_code: hotelA.id, hotela_tag: hotelA.tag, hotelb_code: hotelB.id, hotelb_tag: hotelB.tag)
		end
	end

	def similarity opts = {}
		update(similarity: Hotel.similarity(hotelA, hotelB, opts)) if super() == nil || opts[:reload] == true
		super()
	end

	def hotelA
		Hotel.find(hotela_code)
	end

	def hotelB
		Hotel.find(hotelb_code)
	end

	private
		def check_validates
			return false if self.hotela_tag == self.hotelb_tag
			HotelsSimilarityTable.where(hotela_code: self.hotela_code, hotela_tag: self.hotela_tag, hotelb_code: self.hotelb_code, hotelb_tag: self.hotelb_tag).empty?
		end
end
