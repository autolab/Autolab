class GroupsController < ApplicationController
  before_action :set_assessment
  before_action :set_group, only: [:show, :edit, :update, :destroy, :add, :join, :leave]

  respond_to :html

  action_auth_level :index, :student
  def index
    if @cud.instructor then
      @groups = @assessment.groups
      @assessments = @course.assessments.where('group_size > 1').where.not(id: @assessment.id)
      @grouplessCUDs = @course.course_user_data.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: @assessment.id, membership_status: AssessmentUserDatum::UNCONFIRMED})
    else
      aud = @assessment.aud_for @cud.id
      if aud.group then
        redirect_to [@course, @assessment, aud.group] and return
      else
        redirect_to action: :new and return
      end
    end
    respond_with(@course, @assessment, @groups)
  end

  action_auth_level :show, :student
  def show
    @aud = @assessment.aud_for @cud.id
    unless @cud.instructor? then
      if @aud.group_id == nil then
        redirect_to action: :new and return
      elsif @aud.group_id != params[:id].to_i then
        redirect_to [@course, @assessment, @aud.group] and return
      end
    end
    if @group.size < @assessment.group_size && @group.is_member(@aud) then
      @grouplessCUDs = @assessment.grouplessCUDs
    end
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :new, :student
  def new
    aud = @assessment.aud_for(@cud)
    if aud.group_confirmed && !@cud.instructor then
      redirect_to [@course, @assessment, aud.group] and return
    end
    
    @group = Group.new
    @grouplessCUDs = @assessment.grouplessCUDs
    @groups = @assessment.groups
    
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :create, :student
  def create
    if params[:member_id] then
      if params[:member_id].to_i == @cud.id then
        flash[:error] = "You can't create a group with just yourself"
        redirect_to action: :new and return
      end
      @aud1 = @assessment.aud_for @cud.id
      @aud2 = @assessment.aud_for params[:member_id].to_i
      if @aud1.group_confirmed then
        flash[:error] = "You already have a confirmed group."
        redirect_to action: :new and return
      elsif @aud2.group_confirmed then
        flash[:error] = aud2.course_user_datum.email + " already has a confirmed group."
        redirect_to action: :new and return
      end
      ActiveRecord::Base.transaction do
        @group = Group.new
        @group.name = "Untitled"
        @group.save!
        @aud1.group_id = @group.id
        @aud1.membership_status = AssessmentUserDatum::CONFIRMED
        @aud1.save!
        @aud2.group_id = @group.id
        @aud2.membership_status = AssessmentUserDatum::GROUP_CONFIRMED
        @aud2.save!
      end
    end
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :update, :student
  def update
    if params[:group] then
      flash[:notice] = 'Group was successfully updated.' if @group.update(group_params)
    end
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :destroy, :student
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
 
  action_auth_level :import, :instructor
  def import
    importFrom = @course.assessments.find(params[:importFrom])
    if importFrom then
      #todo
    end
    redirect_to action: :index and return
  end
  
  ##
  # add is when a group adds a student to itself.
  # the student will need to confirm membership with a call to join.
  #
  # member_id - the id of the member to be added
  #
  action_auth_level :add, :student
  def add
    newMember = @assessment.aud_for(params[:member_id].to_i)
    if newMember then
      members = @group.assessment_user_data.all
      # make sure that the group is not too large
      if newMember.group_id != @group.id && members.size >= @assessment.group_size then
        flash[:error] = "This group is at the maximum size for this assessment"
        redirect_to [@course, @assessment, :groups] and return
      end
      # if the new member has no previous group or was already in this group, group-confirm the new member
      if (newMember.membership_status == AssessmentUserDatum::UNCONFIRMED || newMember.group_id == @group.id) then
        newMember.group = @group
        newMember.membership_status |= AssessmentUserDatum::GROUP_CONFIRMED
        newMember.save!
        flash[:success] = "Member confirmed!"
      end
    else
      flash[:error] = "Member #{params[:member_id]} not found"
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
    newMember = @assessment.aud_for(@cud.id)
    if newMember then
      members = @group.assessment_user_data.all
      # make sure that the group is not too large
      if newMember.group_id != @group.id && members.size >= @assessment.group_size then
        flash[:error] = "This group is at the maximum size for this assessment"
        redirect_to [@course, @assessment, :groups] and return
      end
      # if the new member has no previous group or was already in this group, group-confirm the new member
      if (newMember.membership_status == AssessmentUserDatum::UNCONFIRMED || newMember.group_id == @group.id) then
        newMember.group = @group
        newMember.membership_status |= AssessmentUserDatum::MEMBER_CONFIRMED
        newMember.save!
      end
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
    if params[:member_id] then
      leaver = @assessment.aud_for(params[:member_id].to_i)
      booter = @assessment.aud_for(@cud.id)
      if booter.group_id == @group.id && leaver.group_id == @group.id && 
        leaver.membership_status != AssessmentUserDatum::CONFIRMED then
        leaver.group = nil
        leaver.membership_status = AssessmentUserDatum::UNCONFIRMED
        leaver.save!
      end
    else
      leaver = @assessment.aud_for(@cud.id)
      unless leaver.group_id == @group.id then
        redirect_to [@course, @assessment, @group] and return
      end
      leaver.group = nil
      leaver.membership_status = AssessmentUserDatum::UNCONFIRMED
      ActiveRecord::Base.transaction do
        leaver.save!
        if @group.assessment_user_data.size == 0 then
          @group.destroy!
        end
      end
    end
    respond_with(@course, @assessment, @group)
  end

  private
    def set_assessment
      @assessment = @course.assessments.find(params[:assessment_id])
      unless @assessment.has_groups? then
        flash[:error] = "This is a solo assessment."
        redirect_to [@course, @assessment] and return
      end
    end

    def set_group
      @group = Group.find(params[:id])
    end

    def group_params
      params.require(:group).permit(:name)
    end
end
