class GroupsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb
  before_action :set_groups_breadcrumb, except: %i[index]
  before_action :check_assessment_for_groups
  before_action :set_group, only: %i[show edit update destroy add join leave]
  respond_to :html

  ##
  # can be used by instructors to check groups.  Students get redirected,
  #   either to action: :new or to their group page.
  #
  action_auth_level :index, :student
  def index
    unless @cud.instructor
      aud = @assessment.aud_for @cud.id
      if aud.group
        redirect_to(course_assessment_group_path(@course, @assessment, aud.group)) && return
      end

      redirect_to(action: :new) && return
    end

    @groups = @assessment.groups
    @groupAssessments = @course.assessments
                               .where("`group_size` > 1 AND `group_size` <= ?",
                                      @assessment.group_size).where.not(id: @assessment.id)
    @grouplessCUDs = @assessment.grouplessCUDs
    respond_with(@course, @assessment, @groups)
  end

  ##
  # instructors can use this to view groups, and students can view
  #   their own group with it as well
  #
  action_auth_level :show, :student
  def show
    @aud = @assessment.aud_for @cud.id
    unless @cud.instructor
      redirect_to(action: :new) && return if @aud.group_id.nil?

      if @aud.group_id != params[:id].to_i
        redirect_to(course_assessment_group_path(@course, @assessment, @aud.group)) && return
      end
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # lets users create new groups.  students with groups get redirected.
  #
  action_auth_level :new, :student
  def new
    aud = @assessment.aud_for(@cud)
    if !@cud.instructor && aud.group
      redirect_to(course_assessment_group_path(@course, @assessment,
                                               aud.group)) && return
    end

    @group = Group.new
    @unfullGroups = @assessment.groups.all.select do |g|
      g.assessment_user_data.size < @assessment.group_size
    end

    respond_with(@course, @assessment, @group)
  end

  ##
  # Given a member_id or member_email (id taking precedence), this creates
  # a new group, with @cud being confirmed and the member being GROUP_CONFIRMED
  #
  action_auth_level :create, :student
  def create
    if !@assessment.allow_student_assign_group && @cud.student?
      flash[:error] = "You are not allowed to self-assign group for this assessment. "\
        "Contact your instructor for group assignment."
      redirect_to(action: :new) && return
    end

    unless cud2 = get_member_cud
      redirect_to(action: :new) && return
    end

    aud1 = @assessment.aud_for @cud.id
    aud2 = @assessment.aud_for cud2.id
    if aud1.group_confirmed(AssessmentUserDatum::MEMBER_CONFIRMED)
      flash[:error] = "You have already selected a group."
      redirect_to(action: :new) && return
    elsif aud2.group_confirmed(AssessmentUserDatum::MEMBER_CONFIRMED)
      flash[:error] = "#{cud2.email} has already selected a group."
      redirect_to(action: :new) && return
    end

    group = Group.new
    group.name = params[:group_name] || "Untitled"
    ActiveRecord::Base.transaction do
      group.save! # save now so the group gets an id
      aud2.group_id = group.id
      if !@assessment.allow_student_assign_group && !@cud.student?
        # Student self-assignment disabled and instructor/CA assigning group
        # No need for students to confirm membership
        aud2.membership_status = AssessmentUserDatum::CONFIRMED
        # Also, don't add the instructor/CA to the group
      else
        aud2.membership_status = AssessmentUserDatum::GROUP_CONFIRMED

        aud1.group_id = group.id
        aud1.membership_status = AssessmentUserDatum::CONFIRMED
        aud1.save!
      end
      aud2.save!
    end

    flash[:success] = "Group Created!"

    respond_with(@course, @assessment, group)
  end

  ##
  # this is used to update the name of the given group
  #
  action_auth_level :update, :student
  def update
    if params[:group]
      aud = @assessment.aud_for @cud.id
      if @group.is_member(aud) || @cud.instructor
        flash[:notice] = "Group was successfully updated." if @group.update(group_params)
      else
        flash[:error] = "Permission denied."
      end
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # instructors can use this to disband a group.  No CUDs are harmed
  #
  action_auth_level :destroy, :instructor
  def destroy
    ActiveRecord::Base.transaction do
      @group.destroy!
      flash[:success] = "Group was successfully disbanded."
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # attempts to copy the groups from the assessment with importFrom as the id.
  # it will leave currently created groups untouched, and won't work if importFrom
  # has larger groups than this assessment, or no groups at all
  #
  action_auth_level :import, :instructor
  def import
    ass = @course.assessments.find(params[:ass])
    if !ass
      flash[:error] = "Assessment not found."
      redirect_to(action: :index) && return
    elsif !ass.has_groups? || ass.group_size > @assessment.group_size || @assessment.id == ass.id
      flash[:error] = "That assessment cannot be imported."
      redirect_to(action: :index) && return
    end

    ass.groups.each do |g|
      group = Group.new
      group.name = g.name
      count = 0
      g.assessment_user_data.each do |a|
        cud = a.course_user_datum
        aud = @assessment.aud_for cud.id
        next unless aud.group_confirmed(AssessmentUserDatum::UNCONFIRMED)

        aud.group = group
        aud.membership_status = a.membership_status
        count += 1 if aud.save!
      end
      group.save! if count > 0
    end

    flash[:success] = "Groups successfully imported."

    redirect_to(action: :index)
  end

  ##
  # add is when a group adds a student to itself.
  # the student will need to confirm membership with a call to join.
  #
  # member_id - the id of the member to be added
  #
  action_auth_level :add, :student
  def add
    if !@assessment.allow_student_assign_group && @cud.student?
      flash[:error] = "You are not allowed to add members to your group for this assessment. "\
        "Contact your instructor for group assignment."
      redirect_to(action: :index) && return
    end

    unless @group.is_member(@assessment.aud_for(@cud.id)) || @cud.instructor
      redirect_to(course_assessment_groups_path(@course, @assessment)) && return
    end

    cud = get_member_cud || @cud
    flash.delete(:error) # clear the error from get_member_cud

    newMemberAUD = @assessment.aud_for cud.id

    # if we're adding a new member, and not group-confirming someone,
    # make sure that the group is not too large
    unless @group.enough_room_for(newMemberAUD, @assessment.group_size)
      flash[:error] = "This group is at the maximum size for this assessment."
      redirect_to(course_assessment_groups_path(@course, @assessment)) && return
    end

    # if the new member has no previous group or was already in this group,
    # group-confirm the new member
    if newMemberAUD.membership_status == AssessmentUserDatum::UNCONFIRMED ||
       newMemberAUD.group_id == @group.id

      newMemberAUD.group = @group
      if !@assessment.allow_student_assign_group && !@cud.student?
        # Student self-assignment disabled and instructor/CA assigning group
        # No need for students to confirm membership
        newMemberAUD.membership_status = AssessmentUserDatum::CONFIRMED
      else
        newMemberAUD.membership_status |= AssessmentUserDatum::GROUP_CONFIRMED
      end
      newMemberAUD.save!
      flash[:success] = "Group confirmed!"
    else
      flash[:error] = "The student is already in a group."
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # join is when a student asks to join a group.
  # a group-confirmed member of the group will need to confirm membership
  # with a call to add.
  #
  action_auth_level :join, :student
  def join
    if !@assessment.allow_student_assign_group && @cud.student?
      flash[:error] = "You are not allowed to join another group for this assessment. "\
        "Contact your instructor for group assignment."
      redirect_to(action: :new) && return
    end

    newMemberAUD = @assessment.aud_for(@cud.id)

    # make sure that the group is not too large
    unless @group.enough_room_for(newMemberAUD, @assessment.group_size)
      flash[:error] = "This group is at the maximum size for this assessment."
      redirect_to(course_assessment_groups_path(@course, @assessment)) && return
    end

    # if the new member has no previous group or was already in this group,
    # member-confirm the new member
    if newMemberAUD.membership_status == AssessmentUserDatum::UNCONFIRMED ||
       newMemberAUD.group_id == @group.id

      newMemberAUD.group = @group
      newMemberAUD.membership_status |= AssessmentUserDatum::MEMBER_CONFIRMED
      newMemberAUD.save!
      flash[:success] = "Member confirmed!"
    else
      flash[:error] = "You are already in a group."
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # leave will clear a student's membership status with a group
  # students can always leave their own group, and groups can remove
  # a group-confirmed, but not member-confirmed, student
  #
  # member_id - the id of the member, or @cud.id if not present
  #
  action_auth_level :leave, :student
  def leave
    if !@assessment.allow_student_assign_group && @cud.student?
      flash[:error] = "You are not allowed to change your group for this assessment. "\
        "Contact your instructor for group assignment."
      redirect_to(action: :index) && return
    end

    cud = get_member_cud
    if cud
      leaver = @assessment.aud_for(cud.id)
      booter = @assessment.aud_for(@cud.id)

      # Can remove if the booter is a member of the group and the leaver is not confirmed
      can_remove = @group.is_member(booter) &&
                   leaver.membership_status != AssessmentUserDatum::CONFIRMED
      # ... or if the booter is an instructor
      can_remove ||= @cud.instructor
      # ... but only if the leaver is in the group
      can_remove &&= leaver.group_id == @group.id

      if can_remove
        leaver.leave_group
        if @group.is_effectively_empty
          @group.destroy!
          flash[:success] = "Successfully removed #{cud.user.full_name} from group and disbanded " \
                            "group as all remaining members (if any) require group confirmation."
        else
          flash[:success] = "Successfully removed #{cud.user.full_name} from group."
        end

      end
    else
      leaver = @assessment.aud_for(@cud.id)
      flash.delete(:error) # clear the error from get_member_cud

      unless leaver.group_id == @group.id
        flash[:error] = "You are not a member of this group."
        redirect_to(course_assessment_group_path(@course, @assessment, @group)) && return
      end

      ActiveRecord::Base.transaction do
        leaver.leave_group
        if @group.is_effectively_empty
          @group.destroy!
          flash[:success] =
            "Successfully left and disbanded group as all remaining members (if any) "\
              "require group confirmation."
        else
          flash[:success] = "Successfully left group."
        end
      end
      redirect_to(course_assessment_groups_path(@course, @assessment)) && return
    end
    respond_with(@course, @assessment, @group)
  end

private

  def check_assessment_for_groups
    return if @assessment.has_groups?

    flash[:error] = "This is a solo assessment."
    redirect_to(course_assessment_path(@course, @assessment))
  end

  def set_group
    @group = Group.find_by(id: params[:id])
    return if @group

    flash[:error] = "Group not found."
    redirect_to course_assessment_groups_path(@course, @assessment)
  end

  def group_params
    params.require(:group).permit(:name)
  end

  ##
  # returns the cud whose status in the group is being affected
  # or nil if something is amiss.  Will set flash[:error] in that case
  #
  def get_member_cud
    cud = if params[:member_id]
            @course.course_user_data.find(params[:member_id].to_i)
          elsif params[:member_email]
            @course.course_user_data.joins(:user).find_by(users: { email: params[:member_email] })
          end
    if !cud
      flash[:error] = "The given student was not found in this course."
      return nil
    elsif @cud.id == cud.id
      flash[:error] = "You can't create a group with just yourself."
      return nil
    end
    cud
  end

  def set_groups_breadcrumb
    return if @course.nil? || @assessment.nil? || !@cud.instructor?

    @breadcrumbs << (view_context.link_to "Groups",
                                          course_assessment_groups_path(@course, @assessment))
  end
end
