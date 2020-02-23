class TransferSubmissionTweaks < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :submissions, :tweak, :tweak_old
    add_column :submissions, :tweak_id, :integer, :null => true, :default => nil

	  tweaked_submissions = Submission.where("tweak_old != 0")

	  tweaked_submissions.each do |s|
      tweak_type = (s.absolute_tweak ? "points" : "percent")
		  s.tweak = ScoreAdjustment.create(:value => s.tweak_old, 
										                   :kind => tweak_type)
      
		  s.save!
	  end
  end

  def self.down
    remove_column :submissions, :tweak_id
    rename_column :submissions, :tweak_old, :tweak
  end

end
