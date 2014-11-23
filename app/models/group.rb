class Group < ActiveRecord::Base

  ##
  # returns an iterable of AUDs that have confirmed membership
  # in the given CUD's group for the given assessment
  #
  def self.AUDs_for(assessment, cud)
    # get all of the AUDs that this submission concerns
    aud = assessment.aud_for(cud)
    group = aud.get_confirmed_group
    if (not assessment.has_groups?) or (group == nil) then
      [aud]
    else
      group.confirmed_AUDs
    end
  end

  ##
  # returns the AUDs that have confirmed their membership in this group
  #
  def confirmed_AUDs
    assessment_user_data.where(confirmed: true)
  end

end
