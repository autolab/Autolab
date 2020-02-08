class Addpreregistrytime < ActiveRecord::Migration[4.2]
  def self.up
    add_column :meetings, :preregistry_time, :integer
  end

  def self.down
    remove_column :meetings, :preregistry_time
  end
end
