class EnforceUntilOnSchedulers < ActiveRecord::Migration[6.1]
  # Existing schedules had no expiration before this field was added, so preserve
  # that behavior by assigning the maximum supported timestamp (year 9999).
  NO_EXPIRATION = Time.utc(9999, 12, 31, 23, 59, 59)

  def up
    quoted_until = connection.quote_column_name("until")
    execute <<~SQL
      UPDATE scheduler
      SET #{quoted_until} = #{connection.quote(NO_EXPIRATION)}
      WHERE #{quoted_until} IS NULL
    SQL
    change_column_null :scheduler, :until, false
  end

  def down
    change_column_null :scheduler, :until, true
  end
end
