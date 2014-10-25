class AddTweakTypeToSubmissions < ActiveRecord::Migration
  def self.up
  add_column :submissions, :absolute_tweak, :boolean, { :default => true, :null => false }

  Submission.where("tweak <= 1 and tweak >= -1").each do |s|
    s.absolute_tweak = false
    s.save(false)
  end

  end

  def self.down
  remove_column :submissions, :absolute_tweak
  end
end
