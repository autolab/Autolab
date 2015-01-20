class AddDaveStringToSubmissions < ActiveRecord::Migration
  def change
    add_column :submissions, :dave, :string, limit: 255
  end
end
