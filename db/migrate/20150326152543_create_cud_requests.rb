class CreateCudRequests < ActiveRecord::Migration
  def up
    
    add_column :courses, :public, :boolean
    add_column :courses, :requires_permission, :boolean
    add_column :courses, :website_url, :string

    create_table :cud_requests do |t|

      t.timestamps :date, null: false
      t.integer :user_id, null: false
      t.integer :course_id, null: false

    end
  end

  def down
    remove_column :courses, :public
    remove_column :courses, :requires_permission
    remove_column :courses, :website_url

    drop_table :cud_requests
  end


end
