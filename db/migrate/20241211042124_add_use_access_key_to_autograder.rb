class AddUseAccessKeyToAutograder < ActiveRecord::Migration[6.1]
  def change
    add_column :autograders, :use_access_key, :boolean, default: false
  end
end
