class AddAllowedInstancesToCourses < ActiveRecord::Migration[6.1]
  def change
    add_column :courses, :allowed_ec2_instances, :text
  end
end
