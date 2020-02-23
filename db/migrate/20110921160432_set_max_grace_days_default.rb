class SetMaxGraceDaysDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :assessments, :max_grace_days, :integer, :default=>0
  assessments = Assessment.all
  for a in assessments do
    if a.max_grace_days.nil? then
      a.max_grace_days = 0
      a.save(false)
    end
  end
  end

  def self.down
  end
end
