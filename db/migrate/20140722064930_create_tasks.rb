class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.string :name
      t.string :job_type
      t.integer :status
      t.text :options
      t.string :every
      t.string :at

      t.timestamps
    end
  end
end
