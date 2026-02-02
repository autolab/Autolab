class CreateAmiPackageSources < ActiveRecord::Migration[6.1]
  def change
    create_table :ami_package_sources do |t|
      t.references :ami_image, null: false, foreign_key: true

      t.integer :source_type, null: false, default: 0

      t.string :name

      t.string :deb_url

      t.timestamps
    end
  end
end
