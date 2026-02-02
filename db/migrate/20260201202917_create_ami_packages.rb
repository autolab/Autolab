class CreateAmiPackages < ActiveRecord::Migration[6.1]
  def change
    create_table :ami_packages do |t|
      t.references :ami_image, null: false, foreign_key: true

      t.string :name, null: false
      t.string :version

      t.integer :install_type, nul: false, default: 0

      t.references :ami_package_source, foreign_key: true

      t.boolean :validated, default: false
      t.text :validation_error

      t.timestamps
    end

    add_index :ami_packages, [:ami_image_id, :name]
  end
end
