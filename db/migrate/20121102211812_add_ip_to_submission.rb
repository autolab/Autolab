class AddIpToSubmission < ActiveRecord::Migration[4.2]
  def self.up
    add_column :submissions, :submitter_ip, :string, :limit => 40
  end

  def self.down
    remove_column :submissions, :submitter_ip
  end
end
