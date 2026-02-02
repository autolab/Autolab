class BackfillAmiPackagesFromAmiImages < ActiveRecord::Migration[6.1]
  class AmiImage < ApplicationRecord
    self.table_name = "ami_images"
  end

  class AmiPackage < ApplicationRecord
    self.table_name = "ami_packages"

    enum install_type: { apt: 0, deb: 1 }
  end

  def up
    AmiImage.reset_column_information

    AmiImage.find_each do |image|
      next if image.packages.blank?

      image.packages.each_with_index do |package|
        name, version = package.split("=",2)

        AmiPackage.create!(
          ami_image_id: image.id,
          name: name,
          version: version.presence,
          install_type: AmiPackage.install_types[:apt]
        )
      end
    end
  end

  def down
    AmiPackage.delete_all
  end
end
