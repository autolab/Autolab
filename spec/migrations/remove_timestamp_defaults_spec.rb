require "rails_helper"
require Rails.root.join("db/migrate/20261124000000_remove_timestamp_defaults")

RSpec.describe RemoveTimestampDefaults do
  [true, false].each do |existing_defaults|
    it "normalizes defaults when existing timestamp defaults are #{existing_defaults}" do
      # A separate connection with temporary tables cannot change application tables.
      stub_const("MigrationTestRecord", Class.new(ApplicationRecord))
      MigrationTestRecord.abstract_class = true
      MigrationTestRecord.establish_connection(
        ActiveRecord::Base.connection_db_config.configuration_hash
      )
      MigrationTestRecord.connection_pool.with_connection do |connection|
        options = existing_defaults ? { default: -> { "CURRENT_TIMESTAMP" } } : {}
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
        expect(connection.columns(:scheduler).find { |column| column.name == "until" }.null)
          .to be(false)
        expect do
          connection.execute("INSERT INTO scheduler () VALUES ()")
        end.to raise_error(ActiveRecord::StatementInvalid)
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
