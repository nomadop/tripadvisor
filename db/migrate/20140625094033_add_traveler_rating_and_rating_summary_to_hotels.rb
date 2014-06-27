class AddTravelerRatingAndRatingSummaryToHotels < ActiveRecord::Migration
  def change
    add_column :hotels, :traveler_rating, :string
    add_column :hotels, :rating_summary, :string
  end
end
