class AddApplicationIdToSubmissions < ActiveRecord::Migration[4.2]
  def change
    add_column :submissions, :submitted_by_app_id, :integer
  end
end
