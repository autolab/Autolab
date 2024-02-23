class AddDisableNetworkToAssessments < ActiveRecord::Migration[6.1]
  def change
    add_column :assessments, :disable_network, :boolean, default: false
  end
end
