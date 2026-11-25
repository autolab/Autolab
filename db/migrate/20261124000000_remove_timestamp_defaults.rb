class RemoveTimestampDefaults < ActiveRecord::Migration[8.1]
  def change
    # Already-applied migrations are not rerun on existing installations.
    { scheduler: :until, attachments: :release_at }.each do |table, name|
      # MySQL requires the restored default to match the column's fractional precision.
      precision = connection.columns(table).find { |column| column.name == name.to_s }.precision || 0
      change_column_default table, name, from: -> { "CURRENT_TIMESTAMP(#{precision})" }, to: nil
    end
  end
end
