class AddWebsiteToCourse < ActiveRecord::Migration[5.2]
  def up
  	add_column :courses, :website, :string
  end

  def down
  	remove_column :courses, :website
  end
end
