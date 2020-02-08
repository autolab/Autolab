class AddSystemToAnnouncements < ActiveRecord::Migration[4.2]
  def self.up
    add_column :announcements, :system, :boolean, :null => false, :default => false
    Announcement.find_each do |ann|
        ann.update_attribute :system, true if ann.course_id == -1
    end
  end

  def self.down
    remove_column :announcements, :system
  end
end
