class AddCategoryToAssessments < ActiveRecord::Migration[4.2]
  def change
    add_column :assessments, :category_name, :string
    
    Assessment.all.each do |assessment|
      sql = "SELECT name FROM assessment_categories WHERE id=" + assessment.category_id.to_s
		  records_array = ActiveRecord::Base.connection.execute(sql)
	   	
	   	records_array.each do |cat|
    		assessment.category_name = cat[0]
			  assessment.save!
	    end
    end

    remove_column :assessments, :category_id
    drop_table :assessment_categories
  end
end
