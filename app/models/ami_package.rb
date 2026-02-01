class AmiPackage < ApplicationRecord
  belongs_to :ami_image
  belongs_to :ami_package_source, optional: true

  enum install_type: {
    apt: 0,
    deb: 1
  }

  validates :name, presence: true
end