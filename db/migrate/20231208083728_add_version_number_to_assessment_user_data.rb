class AddVersionNumberToAssessmentUserData < ActiveRecord::Migration[6.0]
  def up
    add_column :assessment_user_data, :version_number, :integer
    AssessmentUserDatum.all.each do |aud|
      max_submission_version = Submission.where(course_user_datum_id: aud.course_user_datum_id, assessment_id: aud.assessment_id).maximum(:version)
      if max_submission_version.nil?
        aud.update(version_number: 0)
      else
        aud.update(version_number: test)
      end
    end
  end
  def down
    AssessmentUserDatum.all.each do |aud|
      revert = Submission.where(assessment_user_data: aud, version_number: aud.version_number)
      unless revert.nil?
        aud.update(latest_submission_id: Submission.where(assessment_user_data: aud, version_number: aud.version_number))
      end
    end
    remove_column :assessment_user_data, :version_number, :integer
  end
end
