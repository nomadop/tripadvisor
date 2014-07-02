class AddTagToHotels < ActiveRecord::Migration
  def change
    add_column :hotels, :tag, :string
  end
end
