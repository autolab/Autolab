class RemovePartnersAndUserModule < ActiveRecord::Migration
  def change
    drop_table :user_modules
    remove_column :assessments, :has_partners, :boolean
  end
end
