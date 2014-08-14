class AddTimeSummaryToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :time_summary, :text
  end
end
