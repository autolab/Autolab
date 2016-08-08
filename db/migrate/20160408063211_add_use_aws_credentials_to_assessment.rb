class AddUseAwsCredentialsToAssessment < ActiveRecord::Migration
  def change
	add_column :assessments, :use_aws_credentials, :boolean, :default=>false
  end
end
