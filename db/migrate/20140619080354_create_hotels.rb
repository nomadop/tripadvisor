class CreateHotels < ActiveRecord::Migration
  def change
    create_table :hotels do |t|
      t.string :name
      t.float :rating
      t.integer :review_count
      t.text :location

      t.timestamps
    end
  end
end
