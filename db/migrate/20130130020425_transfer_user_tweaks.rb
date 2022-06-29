class TransferUserTweaks < ActiveRecord::Migration[4.2]
  def self.up
	  rename_column :users, :tweak, :tweak_old
	  add_column :users, :tweak_id, :integer, :null => true, :default => nil

  	tweaked_users = User.where("tweak_old != 0")
	  
    tweaked_users.each do |u|
      tweak_kind = (u.absolute_tweak ? "points" : "percent")

      u.tweak = ScoreAdjustment.create(:kind => tweak_kind,
                                       :value => u.tweak_old)

      # users might not have nicknames
      u.save false
	  end	
  end

  def self.down
    remove_column :users, :tweak_id
	  rename_column :users, :tweak_old, :tweak
  end

end
