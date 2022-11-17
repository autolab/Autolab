class CreateLtiCourseData < ActiveRecord::Migration[6.0]
  def change
    create_table :lti_course_data do |t|
      t.string :context_id
      t.integer :course_id
      t.datetime :last_synced

      t.timestamps
    end
  end
end
