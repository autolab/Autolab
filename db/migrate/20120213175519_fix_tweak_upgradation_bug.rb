class FixTweakUpgradationBug < ActiveRecord::Migration[4.2]
  def self.up
  #User.where("tweak <= 1 and tweak >= -1 and tweak != 0 and absolute_tweak = false").each do |u|
  #  u.tweak = u.tweak * 100
  #  u.save(false)
  #end

  #Submission.where("tweak <= 1 and tweak >= -1 and tweak !=0 and absolute_tweak = false").each do |u|
  #  u.tweak = u.tweak * 100
  #  u.save(false)
  #end

  end

  def self.down
  User.where("absolute_tweak = false").each do |u|
    u.tweak = u.tweak / 100
    u.save(false)
  end

  Submission.where("absolute_tweak = false").each do |u|
    u.tweak = u.tweak / 100
    u.save(false)
  end

  end
end
