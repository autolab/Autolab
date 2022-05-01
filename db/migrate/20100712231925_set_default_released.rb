class SetDefaultReleased < ActiveRecord::Migration[4.2]
  def self.up
    change_column :scores, :released, :boolean, :default=>false
    #Score.update_all("released=?",false],["released = ?",false])
  end

  def self.down
  end
end
