class HotelsSimilarityTable < ActiveRecord::Base
	before_create :check_validates

	private
		def check_validates
			return false if self.hotela_tag == self.hotelb_tag
			HotelsSimilarityTable.where(hotela_code: self.hotela_code, hotela_tag: self.hotela_tag, hotelb_code: self.hotelb_code, hotelb_tag: self.hotelb_tag).empty?
		end
end
