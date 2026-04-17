class CreateSshKeys < ActiveRecord::Migration[4.2]
  def change
    create_table :ssh_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.text :public_key, null: false
      t.string :comment
      t.string :key_type # e.g., "ssh-rsa", "ssh-ed25519", "ecdsa-sha2-nistp256"
      t.string :fingerprint # MD5 or SHA256 fingerprint for identification
      t.boolean :active, default: true, null: false
      t.timestamps null: false
    end

    add_index :ssh_keys, :user_id
    add_index :ssh_keys, :fingerprint, unique: true
    add_index :ssh_keys, :active
  end
end
