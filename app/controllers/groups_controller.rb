class GroupsController < ApplicationController
  before_action :load_assessment
  before_action :set_group, only: [:show, :edit, :update, :destroy]

  # GET /groups
  # GET /groups.json
  action_auth_level :index, :student
  def index
    @groups = Group.all
  end

  # GET /groups/1
  # GET /groups/1.json
  action_auth_level :show, :student
  def show
  end

  # GET /groups/new
  action_auth_level :new, :student
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  action_auth_level :edit, :student
  def edit
  end

  # POST /groups
  # POST /groups.json
  action_auth_level :create, :student
  def create
    @group = Group.new(group_params)

    respond_to do |format|
      if @group.save
        format.html { redirect_to @group, notice: 'Group was successfully created.' }
        format.json { render :show, status: :created, location: @group }
      else
        format.html { render :new }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /groups/1
  # PATCH/PUT /groups/1.json
  action_auth_level :update, :student
  def update
    respond_to do |format|
      if @group.update(group_params)
        format.html { redirect_to @group, notice: 'Group was successfully updated.' }
        format.json { render :show, status: :ok, location: @group }
      else
        format.html { render :edit }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.json
  action_auth_level :destroy, :student
  def destroy
    @group.destroy
    respond_to do |format|
      format.html { redirect_to groups_url, notice: 'Group was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    def load_assessment
      @assessment = @course.assessments.find(params[:assessment_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def group_params
      params.require(:group).permit(:name)
    end
end
