class AddSourceIdToHotels < ActiveRecord::Migration
  def change
    add_column :hotels, :source_id, :integer
  end
end
