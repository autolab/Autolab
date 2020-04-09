class PrepareExternalAuth < ActiveRecord::Migration[4.2]
  def up
    # rename old :users table to :course_user_data table
    rename_table :users, :course_user_data
    
    # create/recover new :users table
    if table_exists? :users_backup then
      rename_table :users_backup, :users
    else
      create_table(:users) do |t|
        ## Database authenticatable
        t.string :email,              :null => false, :default => ""
        t.string :first_name,         :null => false, :default => ""
        t.string :last_name,          :null => false, :default => ""
        t.boolean :administrator,     :null => false, :default => false
        t.string :encrypted_password, :null => false, :default => ""

        ## Recoverable
        t.string   :reset_password_token
        t.datetime :reset_password_sent_at

        ## Rememberable
        t.datetime :remember_created_at

        ## Trackable
        t.integer  :sign_in_count, :default => 0, :null => false
        t.datetime :current_sign_in_at
        t.datetime :last_sign_in_at
        t.string   :current_sign_in_ip
        t.string   :last_sign_in_ip

        ## Confirmable
        t.string   :confirmation_token
        t.datetime :confirmed_at
        t.datetime :confirmation_sent_at
        t.string   :unconfirmed_email # Only if using reconfirmable

        ## Lockable
        # t.integer  :failed_attempts, :default => 0, :null => false # Only if lock strategy is :failed_attempts
        # t.string   :unlock_token # Only if unlock strategy is :email or :both
        # t.datetime :locked_at

        t.timestamps
      end
    
      add_index :users, :email,                :unique => true
      add_index :users, :reset_password_token, :unique => true
      add_index :users, :confirmation_token,   :unique => true
      # add_index :users, :unlock_token,         :unique => true
    end
    
    # create/recover :authentications table
    if table_exists? :authentications_backup then
      rename_table :authentications_backup, :authentications
    else
      create_table :authentications do |t|
        t.string :provider,                     :null => false
        t.string :uid,                          :null => false
        t.belongs_to :user

        t.timestamps
      end
    end
    
    # build relation between :users and :course_user_data
    if column_exists? :course_user_data, :user_id_backup then
      rename_column :course_user_data, :user_id_backup, :user_id
    else
      add_column :course_user_data, :user_id, :integer
      change_column :course_user_data, :user_id, :integer, null: false
    end

    rename_column :course_user_data, :first_name, :first_name_backup
    rename_column :course_user_data, :last_name, :last_name_backup
    rename_column :course_user_data, :andrewID, :andrewID_backup
    change_column :course_user_data, :andrewID_backup, :string, :default => ""
    rename_column :course_user_data, :email, :email_backup
    rename_column :course_user_data, :administrator, :administrator_backup

    # move the data of the old :users table
    CourseUserDatum.find_each do |cud|
      if cud.user.nil? then # no user field
        user = User.where(:email => cud.email_backup).first
        
        if user.nil? then # user haven't been created yet
          # build "CMU-Shibboleth" authentication object
          auth = Authentication.new
          auth.provider = "CMU-Shibboleth"
          auth.uid = cud.andrewID_backup + "@andrew.cmu.edu"
          auth.save!
          
          # build user object
          user = User.new
          user.first_name = cud.first_name_backup
          user.last_name = cud.last_name_backup
          user.email = cud.email_backup
          user.administrator = cud.administrator_backup
          user.authentications << auth
        
          temp_pass = Devise.friendly_token[0,20] # use a random token
          user.password = temp_pass
          user.password_confirmation = temp_pass
          user.skip_confirmation!
        
          user.save!
        end
        cud.user = user
        cud.save!
        user.course_user_data << cud
        user.save!
      end
    end

    # change user reference from other models    
    rename_column :announcements, :user_id, :course_user_datum_id
    # remove this index. Otherwise, Rails will err on long index name
    if index_exists?(:assessment_user_data, ["user_id", "assessment_id"])
      remove_index :assessment_user_data, ["user_id", "assessment_id"]
    end
    rename_column :assessment_user_data, :user_id, 
          :course_user_datum_id
    add_index :assessment_user_data, ["course_user_datum_id", "assessment_id"],
              :name => "index_AUDs_on_CUD_id_and_assessment_id"
    rename_column :extensions, :user_id, :course_user_datum_id
    rename_column :submissions, :user_id, :course_user_datum_id
    
  end
  
  def down
    # recover columns of :course_user_data table
    rename_column :course_user_data, :first_name_backup, :first_name
    rename_column :course_user_data, :last_name_backup, :last_name
    rename_column :course_user_data, :andrewID_backup, :andrewID
    change_column :course_user_data, :andrewID, :string, :default => nil
    rename_column :course_user_data, :email_backup, :email
    rename_column :course_user_data, :administrator_backup, :administrator
    
    # backup cud user_id
    rename_column :course_user_data, :user_id, :user_id_backup
    
    # backup :users table
    rename_table :users, :users_backup
    
    # backup :authentications table
    rename_table :authentications, :authentications_backup
    
    # rename :course_user_data table to :users table
    rename_table :course_user_data, :users
    
    # change user reference from other models
    rename_column :announcements, :course_user_datum_id, :user_id
    remove_index :assessment_user_data, :name => "index_AUDs_on_CUD_id_and_assessment_id"
    rename_column :assessment_user_data, :course_user_datum_id,
          :user_id
    add_index "assessment_user_data", ["user_id", "assessment_id"]
    rename_column :extensions, :course_user_datum_id, :user_id
    rename_column :submissions, :course_user_datum_id, :user_id
    
  end
  
end
