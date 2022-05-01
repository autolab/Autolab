class AddSharedCommentToAnnotations < ActiveRecord::Migration[6.0]
  def change
    add_column :annotations, :shared_comment, :boolean, default: false
  end
end
