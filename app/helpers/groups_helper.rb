module GroupsHelper
  def groups_back_link
    if @cud.instructor
      link_to "Back", course_assessment_groups_path(@course, @assessment)
    else
      link_to "Back", current_assessment_path
    end
  end

  # Whether a user can make certain changes to group membership
  # - cancel outgoing membership requests
  # - confirm / deny incoming membership requests
  # - add users to group (send an outgoing membership request)
  def user_can_edit_group?
    (@group.is_member(@aud) && @assessment.allow_student_assign_group) || @cud.instructor
  end
end
