class AddPositionToAnnotations < ActiveRecord::Migration[4.2]
  def change
  	 add_column :annotations, :coordinate, :string
  end
end
