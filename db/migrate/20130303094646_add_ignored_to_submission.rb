class AddIgnoredToSubmission < ActiveRecord::Migration[4.2]
  def self.up
    # NG => ignored
    add_column :submissions, :ignored, :boolean, :default => false, :null => false
    #Submission.update_all({ :ignored => true }, { :special_type => Submission::NG })
    
    say_with_time "update AUDs with latest *unignored* submissions" do
      Assessment.find_each { |asmt| update_latest_submissions_modulo_callbacks(asmt.id, false) }
    end
  end

  def self.update_latest_submissions_modulo_callbacks(asmt_id, include_ignored)
    calculate_latest_submissions(asmt_id, include_ignored).each do |s|
      AssessmentUserDatum.update_all({ :latest_submission_id => s.id },
                                     { :assessment_id => asmt_id, :user_id => s.user_id })
    end
  end

  def self.calculate_latest_submissions(asmt_id, include_ignored)
    conditions = "assessment_id = #{asmt_id}"
    conditions << " AND ignored = FALSE" unless include_ignored

    max_version_subquery = "SELECT * FROM (SELECT MAX(version), user_id
                            FROM `submissions` WHERE #{conditions}
                            GROUP BY user_id) AS x"
    Submission.find(
      :all,
      :select => "submissions.*",
      :conditions => [ "(version, user_id) IN (#{max_version_subquery}) AND assessment_id = ?", asmt_id ],
    )
  end

  def self.down
    say_with_time "include ignored latest submissions in AUDs again" do
      Assessment.find_each { |asmt| update_latest_submissions_modulo_callbacks(asmt.id, true) }
    end

    # ignored => NG
    Submission.update_all({ :special_type => Submission::NG }, { :ignored => true })
    remove_column :submissions, :ignored
  end
end
