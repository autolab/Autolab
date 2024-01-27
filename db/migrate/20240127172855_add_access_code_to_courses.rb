class AddAccessCodeToCourses < ActiveRecord::Migration[6.1]
  def change
    add_column :courses, :access_code, :string, null: false, default: ''
  end
end
