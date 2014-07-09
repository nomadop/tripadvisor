class AddHotelIdToHotels < ActiveRecord::Migration
  def change
    add_column :hotels, :hotel_id, :integer
  end
end
