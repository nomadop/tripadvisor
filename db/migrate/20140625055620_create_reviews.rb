class CreateReviews < ActiveRecord::Migration
  def change
    create_table :reviews do |t|
      t.integer :review_id
      t.integer :hotel_id
      t.string :title
      t.text :content

      t.timestamps
    end
  end
end
