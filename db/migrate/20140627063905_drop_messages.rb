class DropMessages < ActiveRecord::Migration
  def up
  	drop_table :messages
  end

  def down
    create_table :messages do |t|
      t.text :content

      t.timestamps
    end
  end
end
