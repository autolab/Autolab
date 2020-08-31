class AddCallbackUrlToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :callback_url, :string
  end
end
