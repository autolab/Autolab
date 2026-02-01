class AmiPackageSource < ApplicationRecord
  belongs_to :ami_image
  has_many :ami_packages, dependent: :nullify

  enum source_type: {
    ubuntu_default: 0,
    apt_repo: 1,
    deb_url: 2
  }

  validates :source_type, presence: true

  validates :deb_url, presence: true, if: :deb_url?
end