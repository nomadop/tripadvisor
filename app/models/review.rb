class Review < ActiveRecord::Base
	belongs_to :hotel

	def self.update_or_create_from_hash review_info
		review = Review.find_by(review_id: review_info[:review_id])
		if review
			review.update(review_info)
		else
			Review.create(review_info)
		end
	end

	def self.update_or_create args
		case args
		when Hash
			update_or_create_from_hash(args)
		when Array
			args.map { |arg| update_or_create_from_hash(arg) }
		end
	end
end
