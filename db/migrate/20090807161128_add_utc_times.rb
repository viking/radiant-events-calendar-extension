class AddUtcTimes < ActiveRecord::Migration
  def self.up
    add_column :events, :start_time_utc, :datetime
    add_column :events, :end_time_utc, :datetime
  end

  def self.down
    remove_column :events, :end_time_utc
    remove_column :events, :start_time_utc
  end
end
