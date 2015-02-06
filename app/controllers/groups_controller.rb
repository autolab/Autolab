class GroupsController < ApplicationController
  before_action :set_assessment
  before_action :set_group, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    if @cud.instructor then
      @groups = Group.joins(:assessment_user_data).where(assessment_user_data: {assessment_id: @assessment.id})
    else
      redirect_to action: :new and return
    end
    respond_with(@course, @assessment, @groups)
  end

  def show
    respond_with(@course, @assessment, @group)
  end

  def new
    @group = Group.new
    respond_with(@course, @assessment, @group)
  end

  def edit
  end

  def create
    @group = Group.new(group_params)
    flash[:notice] = 'Group was successfully created.' if @group.save
    respond_with(@course, @assessment, @group)
  end

  def update
    flash[:notice] = 'Group was successfully updated.' if @group.update(group_params)
    respond_with(@course, @assessment, @group)
  end

  def destroy
    @group.destroy
    respond_with(@course, @assessment, @group)
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
