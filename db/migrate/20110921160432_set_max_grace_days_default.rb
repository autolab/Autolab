# frozen_string_literal: true

class SetMaxGraceDaysDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :assessments, :max_grace_days, :integer, default: 0
    assessments = Assessment.all
    assessments.each do |a|
      if a.max_grace_days.nil?
        a.max_grace_days = 0
        a.save(false)
      end
    end
  end

  def self.down; end
end
