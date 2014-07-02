class AddFormatAddressAndStreetAddressAndStarsToHotels < ActiveRecord::Migration
  def change
    add_column :hotels, :format_address, :string
    add_column :hotels, :street_address, :string
    add_column :hotels, :star_rating, :string
  end
end
