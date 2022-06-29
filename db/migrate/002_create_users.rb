class CreateUsers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.string :andrewID
      t.string :school
      t.string :major
      t.integer :year
      t.integer :lecture
      t.string :section
      t.string :grade_policy
      t.references :course
      t.string :email
      t.timestamps
    end

    create_table :courses do |t|
      t.string :name
      t.string :semester
    end   
  end

  def self.down
    drop_table :users
    drop_table :courses
  end
end
