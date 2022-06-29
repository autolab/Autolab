class TransferAssessmentTweaks < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :assessments, :late_penalty, :late_penalty_old
    rename_column :assessments, :version_penalty, :version_penalty_old
    add_column :assessments, :late_penalty_id, :integer, 
                             :null => true, :default => nil
    add_column :assessments, :version_penalty_id, :integer, 
                             :null => true, :default => nil

    tweaked_assessments_late = Assessment.where("late_penalty_old != 0")
    tweaked_assessments_version = Assessment.where("version_penalty_old != 0")
	
    tweaked_assessments_late.each do |l|
      if l.late_penalty_old >= 1 then 
	      late_kind = "points"
        late_value = l.late_penalty_old
      else
        late_kind = "percent"
        late_value = l.late_penalty_old * 100
      end
    
      l.late_penalty = ScoreAdjustment.create(:value => late_value,
									                            :kind => late_kind)
	    l.save!
	  end

	  tweaked_assessments_version.each do |v|
	    if v.version_penalty_old >= 1 then
        version_kind = "points"
        version_value = v.version_penalty_old
      else
        version_kind = "percent"
        version_value = v.version_penalty_old * 100
      end

	    v.version_penalty = ScoreAdjustment.create(:value => version_value,
                                                 :kind => version_kind)
      v.save!
    end 
  end

  def self.down
    remove_column :assessments, :version_penalty_id
    remove_column :assessments, :late_penalty_id
    rename_column :assessments, :version_penalty_old, :version_penalty
    rename_column :assessments, :late_penalty_old, :late_penalty
  end

end
