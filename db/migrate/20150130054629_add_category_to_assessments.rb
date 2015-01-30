class AddCategoryToAssessments < ActiveRecord::Migration
  def change
    add_column :assessments, :category_name, :string
    
    Assessment.all.each do |assessment|
    	assessment.category_name = AssessmentCategory.find_by_id(assessment.category_id).name
    end

    remove_column :assessments, :category_id
    drop_table :assessment_categories
  end
end
