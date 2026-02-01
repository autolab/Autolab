##
# AMI Image Info
#
class AmiImage < ApplicationRecord
  trim_field :name

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  has_many :ami_packages, dependent: :destroy
  has_many :ami_package_sources, through: :ami_packages

  def parse_package(pkg)
    name, version = pkg.split("=", 2)
    if version.nil?
      version = "latest"
    end
    {
      name: name,
      version: version
    }
  end
end
