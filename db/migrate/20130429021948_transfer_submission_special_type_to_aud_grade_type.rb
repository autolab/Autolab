class TransferSubmissionSpecialTypeToAudGradeType < ActiveRecord::Migration[4.2]
  def self.up
    Submission.joins(:assessment_user_datum).where(:special_type => [ Submission::NG, Submission::EXC ]) do |s|
      s.aud.update_attribute(:grade_type, case s.special_type
        when Submission::NG
          AssessmentUserDatum::ZEROED
        when Submission::EXC
          AssessmentUserDatum::EXCUSED
        else
          raise "shouldn't be here"
      end)
    end
  end

  def self.down
    AssessmentUserDatum.update_all(:grade_type => AssessmentUserDatum::NORMAL);
  end
end
