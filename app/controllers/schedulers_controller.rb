##
# Schedulers are used by like buflab and bomblab and that's it.  Tasks don't actually
# get accurately scheduled, but with each request, we check all schedulers, and if one
# hasn't ran in more than its period's time, it's function is run.  This is awful.
#
class SchedulersController < ApplicationController
  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end
  action_auth_level :index, :instructor
  def index
    @schedulers = Scheduler.where(course_id: @course.id)
  end

  action_auth_level :show, :instructor
  def show
    @scheduler = Scheduler.find(params[:id])
  end

  action_auth_level :new, :instructor
  def new; end

  action_auth_level :create, :instructor
  def create
    @scheduler = @course.scheduler.new(scheduler_params)
    if @scheduler.save
      flash[:success] = "Scheduler created!"
      redirect_to(course_schedulers_path(@course)) and return
    else
      flash[:error] = "Create failed. Please check all fields."
      redirect_to(action: "new") and return
    end
  end

  action_auth_level :edit, :instructor
  def edit
    @scheduler = Scheduler.find(params[:id])
  end

  action_auth_level :run, :instructor
  def run
    @scheduler = Scheduler.find(params[:scheduler_id])
  end

  action_auth_level :visual_run, :instructor
  def visual_run
    action = Scheduler.find(params[:scheduler_id])
    @log = "Executing #{Rails.root.join(action.action)}\n"
    mod_name = Rails.root.join(action.action)
    begin
      require mod_name
      Updater.update(action.course)
    rescue ScriptError, StandardError => e
      @log << ("Error in '#{@course.name}' updater: #{e.message}\n")
      @log << (e.backtrace.join("\n\t"))
    end
    @log << "\nCompleted running action."
    render partial: "visual_test"
  end

  action_auth_level :update, :instructor
  def update
    @scheduler = Scheduler.find(params[:id])
    if @scheduler.update(scheduler_params)
      flash[:success] = "Edit success!"
      redirect_to(course_schedulers_path(@course)) and return
    else
      flash[:error] = "Scheduler edit failed! Please check your fields."
      redirect_to(action: "edit") and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @scheduler = Scheduler.find(params[:id])
    if @scheduler.destroy
      flash[:success] = "Scheduler destroyed."
    else
      flash[:error] = "Scheduler destroy failed! Please check your fields."
      redirect_to(action: "edit") and return
    end
    redirect_to(action: "index") and return
  end

private

  def scheduler_params
    params.require(:scheduler).permit(:action, :next, :interval)
  end
end
