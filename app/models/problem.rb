class Problem < ActiveRecord::Base
  trim_field :name

  # don't need :dependent => :destroy as of 2/18/13
  has_many :scores, :dependent => :delete_all
  belongs_to :assessment, :touch => true
  has_many :annotations

  validates_presence_of :name
  validates_associated :assessment

  SERIALIZABLE = Set.new [ "name", "description", "max_score", "optional" ]
  def serialize
    Utilities.serializable attributes, SERIALIZABLE
  end

  def self.deserialize_list problems
    problems.map &:deserialize
  end

  def self.deserialize s
    new s
  end
end
