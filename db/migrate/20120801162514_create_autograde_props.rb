class CreateAutogradeProps < ActiveRecord::Migration[4.2]
	def self.up
		create_table :autograde_props do |t|
			t.integer :assessment_id
			t.integer :autograde_timeout
			t.string :autograde_image
			t.boolean :release_score
		end
	end

	def self.down
		drop_table :autograde_props
	end
end
