class AssessmentCategory < ActiveRecord::Base
  trim_field :name
  validates_length_of :name, :minimum => 1
  validates_uniqueness_of :name , :scope=>:course_id
  has_many :assessments,:foreign_key=>:category_id
  belongs_to :course
  
  
  # getList -  returns a hash of category->id pairs
  def self.getList(course)
    categoryDump = AssessmentCategory.where(course: course)
    categories = {}
    for cat in categoryDump do
      categories[cat.name] = cat.id
    end
    return categories
  end
  
end
