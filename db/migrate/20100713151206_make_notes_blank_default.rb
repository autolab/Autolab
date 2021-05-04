# frozen_string_literal: true

class MakeNotesBlankDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :submissions, :notes, :string, default: ""
    rename_column :submissions, :notesPoints, :notes_points
    change_column :submissions, :notes_points, :integer, default: 0
    Submission.all.each do |sub|
      sub.notes = "" unless sub.notes
      sub.notes_points = 0 unless sub.notes_points
      sub.save
    end
  end

  def self.down
    rename_column :submissions, :notes_points, :notesPoints
  end
end
