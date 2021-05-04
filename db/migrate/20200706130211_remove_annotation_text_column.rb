# frozen_string_literal: true

class RemoveAnnotationTextColumn < ActiveRecord::Migration[5.2]
  def change
    remove_column :annotations, :text
  end
end
