class CreateScoreboardProps < ActiveRecord::Migration
	def self.up
		create_table :scoreboard_props do |t|
			t.integer :assessment_id
			t.string :banner
			t.string :colspec
		end
	end

	def self.down
		drop_table :scoreboard_props
	end
end
