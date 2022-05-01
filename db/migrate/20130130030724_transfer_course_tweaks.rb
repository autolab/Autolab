class TransferCourseTweaks < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :courses, :late_penalty, :late_penalty_old
    rename_column :courses, :version_penalty, :version_penalty_old
    add_column :courses, :late_penalty_id, :integer, :null => true, :default => nil
    add_column :courses, :version_penalty_id, :integer, :null => true, :default => nil

  	courses = Course.all 

	  courses.each do |c|
      late_penalty_old = c.late_penalty_old || 0.0
	    if late_penalty_old >= 1 then
		    late_kind = "points"
		    late_value = late_penalty_old
	    else
		    late_kind = "percent"
		    late_value = late_penalty_old * 100
	    end

	    c.late_penalty = ScoreAdjustment.create(:value => late_value,
  										                        :kind => late_kind)

		  if c.version_penalty_old >= 1 then
			  version_kind = "points"
			  version_value = c.version_penalty_old
		  else
			  version_kind = "percent"
			  version_value = c.version_penalty_old * 100
		  end

		  c.version_penalty = ScoreAdjustment.create(:value => version_value,
												                         :kind => version_kind)
		  c.save!
    end
  end

  def self.down
    remove_column :courses, :version_penalty_id
    remove_column :courses, :late_penalty_id
    rename_column :courses, :version_penalty_old, :version_penalty
    rename_column :courses, :late_penalty_old, :late_penalty
  end

end
