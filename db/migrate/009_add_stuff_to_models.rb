class AddStuffToModels < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :administrator, :boolean, :options=>{:default=>false}
    add_column :assignments, :category, :string
    add_column :users, :dropped, :boolean, :options=>{:default=>false}
    add_column :scores, :released, :boolean, :options=>{:default=>false}
    add_column :submissions, :notes, :text
    add_column :submissions, :notesPoints, :integer
  
    User.update_all({:administrator=>false,:dropped=>false})
    Score.update_all({:released=>false})

  end

  def self.down
    remove_column :users, :administrator
    remove_column :assignments, :category
    remove_column :users, :dropped
    remove_column :scores, :released
    remove_column :submissions, :notes
    remove_column :submissions, :notesPoints

  end
end
