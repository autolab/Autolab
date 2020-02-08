class CreateAssessmentUserData < ActiveRecord::Migration[4.2]
  def self.initialize_AUDs_modulo_callbacks(asmt)
    # create all AUDs
    Rails.logger.info "Creating AUDs for #{asmt.course.name}/#{asmt.name}..."
    create_AUDs_modulo_callbacks asmt

    # update latest submissions
    Rails.logger.info "Updating AUDs with latest submissions..."
    update_latest_submissions_modulo_callbacks asmt
  end

  def self.create_AUDs_modulo_callbacks(asmt)
    asmt.course.users.find_each { |user|
      create_AUD_modulo_callbacks(asmt.id, user.id)
    }
  end

  def self.create_AUD_modulo_callbacks(asmt_id, user_id)
    insert_sql = "INSERT INTO #{AssessmentUserDatum.table_name} 
                  (assessment_id, user_id) VALUES (#{asmt_id}, #{user_id})"
    AssessmentUserDatum.connection.execute insert_sql
  end

  def self.update_latest_submissions_modulo_callbacks(asmt)
    calculate_latest_submissions(asmt.id).each do |s|
      AssessmentUserDatum.update_all({ :latest_submission_id => s.id },
                                     { :assessment_id => asmt.id, :user_id => s.user_id })
    end
  end

  def self.calculate_latest_submissions(asmt_id)
    max_version_subquery = "SELECT MAX(version), user_id
                            FROM `submissions`
                            WHERE assessment_id = #{asmt_id}
                            GROUP BY user_id"

    subquery_speed_hack = "SELECT * FROM (#{max_version_subquery}) AS x"

    Submission.find(
      :all,
      :select => "submissions.*",
      :conditions => [ "(version, user_id) IN (#{subquery_speed_hack})
                        AND assessment_id = ?", asmt_id ]
    )
  end

  def self.up
    create_table :assessment_user_data do |t|
      t.integer :user_id, :null => false
      t.integer :assessment_id, :null => false
      t.integer :latest_submission_id
      
      t.timestamps
    end

    add_index :assessment_user_data, :user_id
    add_index :assessment_user_data, :assessment_id
    add_index :assessment_user_data, :latest_submission_id, :unique => true
    add_index :assessment_user_data, [ :user_id, :assessment_id ], :unique => true

    Assessment.find_each { |asmt| initialize_AUDs_modulo_callbacks asmt }
  end

  def self.down
    drop_table :assessment_user_data
  end
end
