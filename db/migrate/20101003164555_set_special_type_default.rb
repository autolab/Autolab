class SetSpecialTypeDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :submissions, :special_type, :integer, :default=>0
    Submission.all.each do |subs|
      for s in subs do
        if s.special_type == nil then
          s.special_type= 0
          s.save(false)
        end
      end
    end
  end

  def self.down
  end
end
