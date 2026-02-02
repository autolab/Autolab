class CreateAmiImages < ActiveRecord::Migration[6.1]
  def change
    create_table :ami_images do |t|
      t.string :name
      t.json :packages, default: []

      t.timestamps
    end
  end
end
