class AddAwsJobFieldsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :aws_job_id, :string
    add_column :users, :aws_job_status, :string
  end
end
