class AddTangoJobIdToSubmissions < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :tango_job_id, :integer
  end
end
