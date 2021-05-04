# frozen_string_literal: true

class SetSpecialTypeDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :submissions, :special_type, :integer, default: 0
    Submission.all.each do |subs|
      subs.each do |s|
        if s.special_type.nil?
          s.special_type = 0
          s.save(false)
        end
      end
    end
  end

  def self.down; end
end
