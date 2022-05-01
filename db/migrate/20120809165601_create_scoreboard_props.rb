class CreateScoreboardProps < ActiveRecord::Migration[4.2]
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
