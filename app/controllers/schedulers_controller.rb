class SchedulersController < ApplicationController

  action_auth_level :index, :instructor
  def index
    @schedulers = Scheduler.where(:course_id => @course.id)
  end

  action_auth_level :show, :instructor
  def show
    @scheduler = Scheduler.find(params[:id])
  end

  action_auth_level :new, :instructor
  def new

  end

  action_auth_level :create, :instructor
  def create
    @scheduler = @course.scheduler.new(scheduler_params)
    if @scheduler.save then
      flash[:success] = "Scheduler created!"
      redirect_to course_schedulers_path(@course) and return
    else
      flash[:error] = "Create failed! Pleaes check all fields."
      redirect_to :action => "new" and return
    end
  end

  action_auth_level :edit, :instructor
  def edit
    @scheduler = Scheduler.find(params[:id])
  end

  action_auth_level :update, :instructor
  def update
    @scheduler = Scheduler.find(params[:id])
    if @scheduler.update(scheduler_params) then
      flash[:success] = "Edit success!"
      redirect_to course_schedulers_path(@course) and return
    else
      flash[:error] = "Schedular Edit failed! Please check your fields."
      redirect_to :action => "edit" and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @scheduler = Scheduler.find(params[:id])
    @scheduler.destroy() # boo
    redirect_to :action=>"index" and return
  end

  private

  def scheduler_params
    params.require(:scheduler).permit(:action, :next, :interval)
  end

end
