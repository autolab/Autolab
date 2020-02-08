class AddModuleTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :module_data do |t|
      t.references :field
      t.integer :data_id
      t.binary :data
    end
    create_table :module_fields do |t|
      t.references :user_module
      t.string :name
      t.string :data_type
    end
    create_table :user_modules do |t|
      t.references :course
      t.string :name
    end
  end

  def self.down
    drop_table :module_data
    drop_table :module_fields
    drop_table :user_modules
  end
end
