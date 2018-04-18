class AddApplicationIdToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :submitted_by_app_id, :integer
  end
end
