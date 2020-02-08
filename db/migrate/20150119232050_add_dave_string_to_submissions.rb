class AddDaveStringToSubmissions < ActiveRecord::Migration[4.2]
  def change
    add_column :submissions, :dave, :string, limit: 255
  end
end
