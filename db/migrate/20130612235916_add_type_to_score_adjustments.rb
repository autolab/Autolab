class AddTypeToScoreAdjustments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :score_adjustments, :type, :string, :default => "Tweak", :null => false

    Course.find_each do |c|
      self.set_type c.late_penalty_id, "Penalty"
      self.set_type c.version_penalty_id, "Penalty"
    end

    Assessment.find_each do |a|
      self.set_type a.late_penalty_id, "Penalty"
      self.set_type a.version_penalty_id, "Penalty"
    end

    User.find_each do |u|
      self.set_type u.tweak_id, "Tweak"
    end

    Submission.find_each do |s|
      self.set_type s.tweak_id, "Tweak"
    end
  end

  def self.set_type(sa_id, type)
    ScoreAdjustment.update_all({ :type => type }, { :id => sa_id }) if sa_id
  end

  def self.down
    remove_column :score_adjustments, :type
  end
end
