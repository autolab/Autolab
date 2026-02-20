##
# AMI Image Info
#
class AmiImage < ApplicationRecord
  trim_field :name

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  has_many :ami_packages, dependent: :destroy
  has_many :ami_package_sources, dependent: :destroy
  has_many :autograders

  belongs_to :course

  def emit_packages
    ami_packages.map do |package|
      deb_url = if package.install_type == "deb"
                  package.ami_package_source.deb_url
                else
                  ""
                end
      {
        name: package.name,
        version: package.version,
        install_type: package.install_type,
        deb_url: deb_url
      }
    end
  end

  def self.emit_arn
    AmiImage.all.map do |image|
      {
        id: image.id,
        execution_arn: image.execution_arn,
      }
    end
  end
end
