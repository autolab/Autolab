class GroupsController < ApplicationController
  before_action :set_assessment
  before_action :set_group, only: [:show, :edit, :update, :destroy]

  respond_to :html

  action_auth_level :index, :student
  def index
    if @cud.instructor then
      @groups = Group.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: @assessment.id}).distinct
      @assessments = @course.assessments.where('group_size > 1').where.not(id: @assessment.id)
      @grouplessCUDs = @course.course_user_data.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: @assessment.id, group_confirmed: false})
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
    if !@cud.instructor? then
      puts @aud.group_id, params[:id]
      if @aud.group_id == nil then
        redirect_to action: :new and return
      elsif @aud.group_id != params[:id].to_i then
        puts "this some old bull shit"
        redirect_to [@course, @assessment, @aud.group] and return
      end
    end
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :new, :student
  def new
    @group = Group.new
    @grouplessCUDs = @course.course_user_data.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: @assessment.id, group_confirmed: false})
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :edit, :student
  def edit
  end

  action_auth_level :create, :student
  def create
    if params[:groupmate_id] then
      if params[:groupmate_id] == @cud.id then
        flash[:error] = "You can't create a group with just yourself"
        redirect_to action: :new and return
      end
      @aud1 = @assessment.aud_for @cud.id
      @aud2 = @assessment.aud_for params[:groupmate_id]
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
        @aud1.group_confirmed = true
        @aud1.save!
        @aud2.group_id = @group.id
        @aud2.group_confirmed = false
        @aud2.save!
      end
    else
      @group = Group.new(group_params)
      flash[:notice] = 'Group was successfully created.' if @group.save
    end
    respond_with(@course, @assessment, @group)
  end

  action_auth_level :update, :student
  def update
    if params[:addMember] then
      addAUD = @assessment.aud_for(params[:addMember])
      unless addAUD.group_confirmed then
        cudAUD = @assessment.aud_for @cud.id
        confirmed = @cud.instructor? || (params[:confirmed] && (cudAUD == addAUD))
        addAUD.group = @group
        addAUD.group_confirmed = confirmed
        addAUD.save!
      end
    end
    if params[:removeMember] then
      aud = @group.assessment_user_data.find(params[:removeMember])
      authed = @cud.instructor? || (@assessment.aud_for @cud.id == aud)
      unless aud.nil? || !authed then
        aud.group = nil
        aud.group_confirmed = false
        aud.save!
      end
    end
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
        aud.group_confirmed = false
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
    
  action_auth_level :confirm, :student
  def confirm
    
  end

  private
    def set_assessment
      @assessment = @course.assessments.find(params[:assessment_id])
    end

    def set_group
      @group = Group.find(params[:id])
    end

    def group_params
      params.require(:group).permit(:name)
    end
end
