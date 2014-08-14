class CreateHotelsSimilarityTables < ActiveRecord::Migration
  def change
    create_table :hotels_similarity_tables do |t|
      t.integer :hotela_code
      t.string :hotela_tag
      t.integer :hotelb_code
      t.string :hotelb_tag
      t.float :similarity

      t.timestamps
    end
  end
end
