require "rails_helper"
require Rails.root.join("db/migrate/20261124000000_remove_timestamp_defaults")

RSpec.describe RemoveTimestampDefaults do
  sql_modes = ["NO_ENGINE_SUBSTITUTION", "STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION"]
  [true, false].product(sql_modes, [0, 6]).each do |existing_defaults, sql_mode, precision|
    description = "defaults: #{existing_defaults}, SQL mode: #{sql_mode}, precision: #{precision}"
    it "normalizes timestamp defaults (#{description})" do
      # A separate connection with temporary tables cannot change application tables.
      stub_const("MigrationTestRecord", Class.new(ApplicationRecord))
      MigrationTestRecord.abstract_class = true
      configuration = ActiveRecord::Base.connection_db_config.configuration_hash
      MigrationTestRecord.establish_connection(
        configuration.merge(variables: { sql_mode: sql_mode })
      )
      MigrationTestRecord.connection_pool.with_connection do |connection|
        # Exercise both legacy columns and fresh schemas with fractional timestamps.
        options = { precision: precision }
        options[:default] = -> { "CURRENT_TIMESTAMP(#{precision})" } if existing_defaults
        connection.create_table(:scheduler, temporary: true) do |table|
          table.datetime :until, null: false, **options
        end
        connection.create_table(:attachments, temporary: true) do |table|
          table.datetime :release_at, **options
        end
        connection.execute("INSERT INTO scheduler (`until`) VALUES ('2030-01-01 00:00:00')")
        connection.execute("INSERT INTO attachments (release_at) VALUES ('2030-01-01 00:00:00')")

        described_class.new.exec_migration(connection, :up)

        [:scheduler, :attachments].zip(["until", "release_at"]).each do |table, name|
          column = connection.columns(table).find { |entry| entry.name == name }
          expect(column.default).to be_nil
          expect(column.default_function).to be_nil
          expect(connection.select_value("SELECT YEAR(`#{name}`) FROM #{table}")).to eq(2030)
        end
        # Check the constraint directly: non-strict MySQL coerces missing NOT NULL values.
        expect(connection.columns(:scheduler).find { |column| column.name == "until" }.null)
          .to be(false)
        connection.execute("INSERT INTO attachments () VALUES ()")
        query = "SELECT release_at FROM attachments ORDER BY id DESC LIMIT 1"
        expect(connection.select_value(query)).to be_nil

        described_class.new.exec_migration(connection, :down)

        [:scheduler, :attachments].zip(["until", "release_at"]).each do |table, name|
          column = connection.columns(table).find { |entry| entry.name == name }
          expect(column.default_function).to match(/current_timestamp/i)
        end
      end
    ensure
      MigrationTestRecord.remove_connection
    end
  end
end
