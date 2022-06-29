class MakeNotesBlankDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :submissions, :notes, :string, :default=>""
    rename_column :submissions, :notesPoints, :notes_points
    change_column :submissions, :notes_points, :integer, :default=>0
    Submission.all.each do |sub|
      if ! sub.notes then
        sub.notes = ""
      end
      if ! sub.notes_points then
        sub.notes_points = 0
      end
      sub.save
    end
  end

  def self.down
    rename_column :submissions, :notes_points, :notesPoints
  end
end
