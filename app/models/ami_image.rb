##
# AMI Image Info
#
class AmiImage < ApplicationRecord
  trim_field :name

  validates :name, presence: true, uniqueness: { case_sensitive: false }

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
