class AddCourseToAmiImages < ActiveRecord::Migration[6.1]
  def change
    add_reference :ami_images, :course, null: true, foreign_key: true
  end
end
