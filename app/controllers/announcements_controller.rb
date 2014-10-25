class AnnouncementsController < ApplicationController

  action_auth_level :index, :instructor
  def index
    if @cud.user.administrator? then
      @announcements = Announcement.where("course_id=? or system", @course.id)
    else
      @announcements = Announcement.where(course_id: @course.id)
    end
  end
  
  action_auth_level :new, :instructor
  def new
    # for consistency with REST
  end

  action_auth_level :create, :instructor
  def create
    if !@cud.user.administrator? && params[:announcement][:system] then
      flash[:error] = "You don't have the permission to create system announcements!"
      redirect_to :action => "index" and return
    end
    @announcement = @course.announcements.create(announcement_params)
    if @announcement.save then
      flash[:success] = "Create success!"
      redirect_to course_announcements_path(@course) and return
    else
      flash[:error] = "Create failed! Check all fields."
      redirect_to 'new' and return
    end
  end
  
  action_auth_level :show, :instructor
  def show
    # for consistency with REST
  end

  action_auth_level :edit, :instructor
  def edit
    @announcement = Announcement.find(params[:id])
    # Prevent non-admin from entering system announcements edit page
    if !@cud.user.administrator? && @announcement.system then
      flash[:error] = "You don't have the permission to edit system announcements!"
      redirect_to :action=>"index" and return
    end
  end

  action_auth_level :update, :instructor
  def update
    @announcement = Announcement.find(params[:id])
    if @announcement.update(announcement_params) then
      flash[:success] = "Edit Success!"
      redirect_to course_announcements_path(@course) and return
    else
      flash[:error] = "Edit Failed!"
      redirect_to 'edit' and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @announcement = Announcement.find(params[:id])
    if !@cud.user.administrator? && @announcement.system then
      flash[:error] = "You don't have the permission to destroy system announcements!"
      redirect_to :action=>"index" and return
    end
    @announcement.destroy
    redirect_to :action=>"index"
  end

private
  
  def announcement_params
    params.require(:announcement).permit(:title, :description, :start_date, :end_date, :system, :persistent)
  end

end
