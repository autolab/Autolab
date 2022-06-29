class AddSettingsToSubmissions < ActiveRecord::Migration[4.2]
  def up
        add_column :submissions, :settings, :text
    end

    def down
        remove_column :submissions, :settings
    end
end
