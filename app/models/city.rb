class City < ActiveRecord::Base
	validates_uniqueness_of :name
	validates_uniqueness_of :code

	has_many :hotels
end
