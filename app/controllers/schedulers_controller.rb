##
# Schedulers are used by like buflab and bomblab and that's it.  Tasks don't actually
# get accurately scheduled, but with each request, we check all schedulers, and if one
# hasn't ran in more than its period's time, it's function is run.  This is awful.
#
class SchedulersController < ApplicationController
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
      redirect_to(course_schedulers_path(@course))
    else
      flash[:error] = "Scheduler create failed. Please check all fields."
      redirect_to(new_course_scheduler_path(@course))
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
    # https://stackoverflow.com/a/1076445
    read, write = IO.pipe
    @log = "Executing #{Rails.root.join(action.action)}\n"
    begin
      pid = fork do
        read.close
        mod_name = Rails.root.join(action.action).to_path
        fork_log = ""
        begin
          require mod_name
          output = Updater.update(action.course)
          if output
            fork_log << "----- Script Output -----\n"
            fork_log << output
            fork_log << "\n----- End Script Output -----"
          end
        rescue ScriptError, StandardError => e
          fork_log << "----- Script Error Output -----\n"
          fork_log << "Error in '#{@course.name}' updater: #{e.message}\n"
          fork_log << e.backtrace.join("\n\t")
          fork_log << "\n---- End Script Error Output -----"
        end
        write.print fork_log
      end

      write.close
      result = read.read
      Process.wait2(pid)
      @log << result
    rescue StandardError => e
      @log << "----- Error Output -----\n"
      @log << "Error in '#{@course.name}' updater: #{e.message}\n"
      @log << e.backtrace.join("\n\t")
      @log << "\n---- End Error Output -----"
    end
    @log << "\nCompleted running action."
    render partial: "visual_test"
  end

  action_auth_level :update, :instructor
  def update
    @scheduler = Scheduler.find(params[:id])
    if @scheduler.update(scheduler_params)
      flash[:success] = "Scheduler updated."
      redirect_to(course_schedulers_path(@course))
    else
      flash[:error] = "Scheduler update failed! Please check your fields."
      redirect_to(edit_course_scheduler_path(@course, @scheduler))
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @scheduler = Scheduler.find(params[:id])
    if @scheduler.destroy
      flash[:success] = "Scheduler destroyed."
      redirect_to(course_schedulers_path(@course))
    else
      flash[:error] = "Scheduler destroy failed! Please check your fields."
      redirect_to(edit_course_scheduler_path(@course, @scheduler))
    end
  end

private

  def scheduler_params
    params.require(:scheduler).permit(:action, :next, :until, :interval, :disabled)
  end
end
