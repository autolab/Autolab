module GroupsHelper
  def groups_back_link
    if @cud.instructor
      link_to "Back", course_assessment_groups_path(@course, @assessment)
    else
      link_to "Back", current_assessment_path
    end
  end
end
