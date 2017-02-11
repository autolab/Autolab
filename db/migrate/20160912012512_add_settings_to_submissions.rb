class AddSettingsToSubmissions < ActiveRecord::Migration
  def up
        add_column :submissions, :settings, :text
    end

    def down
        remove_column :submissions, :settings
    end
end
