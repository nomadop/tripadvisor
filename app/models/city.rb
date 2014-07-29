class City < ActiveRecord::Base
	validates_uniqueness_of :name

	has_many :hotels
end
