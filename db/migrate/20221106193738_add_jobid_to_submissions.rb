class AddJobidToSubmissions < ActiveRecord::Migration[6.0]
  def change
    add_column :submissions, :jobid, :integer
  end
end
