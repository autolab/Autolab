class CreateOauthDeviceFlowTables < ActiveRecord::Migration[4.2]
  def change
    create_table :oauth_device_flow_requests do |t|
      t.references :application,     null: false
      t.string   :scopes,            null: false, default: ''
      t.string   :device_code,       null: false
      t.string   :user_code,         null: false
      t.datetime :requested_at,      null: false
      t.integer  :resolution,        null: false, default: 0
      t.datetime :resolved_at
      t.integer  :resource_owner_id
      t.string   :access_code
    end

    add_index :oauth_device_flow_requests, :device_code, unique: true
    add_index :oauth_device_flow_requests, :user_code, unique: true
    add_foreign_key(
      :oauth_device_flow_requests,
      :oauth_applications,
      column: :application_id
    )
  end
end