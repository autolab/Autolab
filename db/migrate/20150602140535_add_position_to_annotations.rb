class AddPositionToAnnotations < ActiveRecord::Migration
  def change
  	 add_column :annotations, :coordinate, :string
  end
end
