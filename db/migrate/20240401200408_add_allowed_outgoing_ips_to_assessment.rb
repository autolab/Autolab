class AddAllowedOutgoingIPsToAssessment < ActiveRecord::Migration[6.1]
  def change
    add_column :assessments, :allowed_outgoing_ips, :string
  end
end
