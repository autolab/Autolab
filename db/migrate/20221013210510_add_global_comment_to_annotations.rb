class AddGlobalCommentToAnnotations < ActiveRecord::Migration[6.0]
  def change
    add_column :annotations, :global_comment, :boolean, default: false
  end
end
