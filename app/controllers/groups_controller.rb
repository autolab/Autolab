class GroupsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :check_assessment_for_groups
  before_action :set_group, only: [:show, :edit, :update, :destroy, :add, :join, :leave]
  respond_to :html
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  ##
  # can be used by instructors to check groups.  Students get redirected,
  #   either to action: :new or to their group page.
  #
  action_auth_level :index, :student
  def index
    unless @cud.instructor
      aud = @assessment.aud_for @cud.id
      if aud.group
        redirect_to([@course, @assessment, aud.group]) && return
      else
        redirect_to(action: :new) && return
      end
    end

    @groups = @assessment.groups
    @groupAssessments = @course.assessments
                        .where("`group_size` > 1 AND `group_size` <= ?", @assessment.group_size).where.not(id: @assessment.id)
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
      if @aud.group_id.nil?
        redirect_to(action: :new) && return
      elsif @aud.group_id != params[:id].to_i
        redirect_to([@course, @assessment, @aud.group]) && return
      end
    end

    if @group.size < @assessment.group_size && @group.is_member(@aud)
      @grouplessCUDs = @assessment.grouplessCUDs
    end
    respond_with(@course, @assessment, @group)
  end

  ##
  # lets users create new groups.  students with groups get redirected.
  #
  action_auth_level :new, :student
  def new
    aud = @assessment.aud_for(@cud)
    unless @cud.instructor
      redirect_to([@course, @assessment, aud.group]) && return if aud.group
    end

    @group = Group.new
    @grouplessCUDs = @assessment.grouplessCUDs
    @unfullGroups = @assessment.groups.all.select { |g| g.assessment_user_data.size < @assessment.group_size }

    respond_with(@course, @assessment, @group)
  end

  ##
  # Given a member_id or member_email (id taking precidence), this creates
  # a new group, with @cud being confirmed and the member being GROUP_CONFIRMED
  #
  action_auth_level :create, :student
  def create
    unless cud2 = get_member_cud
      redirect_to(action: :new) && return
    end

    aud1 = @assessment.aud_for @cud.id
    aud2 = @assessment.aud_for cud2.id
    if aud1.group_confirmed(AssessmentUserDatum::MEMBER_CONFIRMED)
      flash[:error] = "You have already selected a group."
      redirect_to(action: :new) && return
    elsif aud2.group_confirmed(AssessmentUserDatum::MEMBER_CONFIRMED)
      flash[:error] = cud2.email + " has already selected a group."
      redirect_to(action: :new) && return
    end

    group = Group.new
    group.name = params[:group_name] || "Untitled"
    ActiveRecord::Base.transaction do
      group.save! # save now so the group gets an id
      aud1.group_id = group.id
      aud1.membership_status = AssessmentUserDatum::CONFIRMED
      aud1.save!
      aud2.group_id = group.id
      aud2.membership_status = AssessmentUserDatum::GROUP_CONFIRMED
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
      @group.assessment_user_data.each do |aud|
        aud.group_id = nil
        aud.membership_status = AssessmentUserDatum::UNCONFIRMED
        aud.save!
      end
      @group.destroy!
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
        if aud.group_confirmed(AssessmentUserDatum::UNCONFIRMED)
          aud.group = group
          aud.membership_status = a.membership_status
          count += 1 if aud.save!
        end
      end
      group.save! if count > 0
    end

    flash[:success] = "Groups Successfully Imported"

    redirect_to(action: :index) && return
  end

  ##
  # add is when a group adds a student to itself.
  # the student will need to confirm membership with a call to join.
  #
  # member_id - the id of the member to be added
  #
  action_auth_level :add, :student
  def add
    unless @group.is_member(@assessment.aud_for(@cud.id)) || @cud.instructor
      redirect_to([@course, @assessment, :groups]) && return
    end
    unless cud = get_member_cud
      redirect_to([@course, @assessment, @group]) && return
    end
    newMemberAUD = @assessment.aud_for cud.id

    # if we're adding a new member, and not group-confirming someone, make sure that the group is not too large
    unless @group.enough_room_for(newMemberAUD, @assessment.group_size)
      flash[:error] = "This group is at the maximum size for this assessment."
      redirect_to([@course, @assessment, :groups]) && return
    end

    # if the new member has no previous group or was already in this group, group-confirm the new member
    if newMemberAUD.membership_status == AssessmentUserDatum::UNCONFIRMED || newMemberAUD.group_id == @group.id
      newMemberAUD.group = @group
      newMemberAUD.membership_status |= AssessmentUserDatum::GROUP_CONFIRMED
      newMemberAUD.save!
      flash[:success] = "Group confirmed!"
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
    newMemberAUD = @assessment.aud_for(@cud.id)

    # make sure that the group is not too large
    unless @group.enough_room_for(newMemberAUD, @assessment.group_size)
      flash[:error] = "This group is at the maximum size for this assessment"
      redirect_to([@course, @assessment, :groups]) && return
    end

    # if the new member has no previous group or was already in this group, group-confirm the new member
    if newMemberAUD.membership_status == AssessmentUserDatum::UNCONFIRMED || newMemberAUD.group_id == @group.id
      newMemberAUD.group = @group
      newMemberAUD.membership_status |= AssessmentUserDatum::MEMBER_CONFIRMED
      newMemberAUD.save!
      flash[:success] = "Membership confirmed!"
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
    cud = get_member_cud
    if cud
      leaver = @assessment.aud_for(cud.id)
      booter = @assessment.aud_for(@cud.id)
      if @group.is_member(booter) && leaver.group_id == @group.id &&
         leaver.membership_status != AssessmentUserDatum::CONFIRMED
        leaver.group = nil
        leaver.membership_status = AssessmentUserDatum::UNCONFIRMED
        leaver.save!
      end
    else
      leaver = @assessment.aud_for(@cud.id)
      unless leaver.group_id == @group.id
        redirect_to([@course, @assessment, @group]) && return
      end
      leaver.group = nil
      leaver.membership_status = AssessmentUserDatum::UNCONFIRMED
      ActiveRecord::Base.transaction do
        leaver.save!
        @group.destroy! if @group.assessment_user_data.size == 0
      end
    end
    respond_with(@course, @assessment, @group)
  end

private

  def check_assessment_for_groups
    unless @assessment.has_groups?
      flash[:error] = "This is a solo assessment."
      redirect_to([@course, @assessment]) && return
    end
  end

  def set_group
    @group = Group.find(params[:id])
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
          else
            nil
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
end
