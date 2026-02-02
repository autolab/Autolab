class AddDebUrlIndexToAmiPackages < ActiveRecord::Migration[6.1]
  def change
    add_index :ami_packages, :deb_url
  end
end
