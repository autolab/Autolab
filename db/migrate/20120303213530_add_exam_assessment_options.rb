class AddExamAssessmentOptions < ActiveRecord::Migration[4.2]
  def self.up
    change_table :assessments do |t|
        t.boolean :exam, :default => false
    end
    change_table :courses do |t|
        t.boolean :exam_in_progress, :default => false
    end
  end

  def self.down
    remove_column :assessments, :exam
    remove_column :courses, :exam_in_progress
  end
end
