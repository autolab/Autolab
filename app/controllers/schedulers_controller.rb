##
# Schedulers are used by like buflab and bomblab and that's it.  Tasks don't actually
# get accurately scheduled, but with each request, we check all schedulers, and if one
# hasn't ran in more than its period's time, it's function is run.  This is awful.
#
class SchedulersController < ApplicationController
  before_action :set_manage_course_breadcrumb
  before_action :set_manage_scheduler_breadcrumb, except: %i[index]

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
    action_path = Rails.root.join(scheduler_params[:action]).to_path
    # Check if the action file exists, is readable, and compiles
    if validate_compile_action_file(action_path)
      if @scheduler.save
        # Ensure visual run is successful
        if run_visual_scheduler(@scheduler)
          flash[:success] = "Scheduler created and executed successfully!"
          redirect_to(course_schedulers_path(@course)) and return
        else
          @scheduler.destroy
          flash[:error] = "Scheduler creation failed during execution."
        end
      else
        flash[:error] = "Scheduler create failed. Please check all fields."
      end
    end
    redirect_to(new_course_scheduler_path(@course))
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
    @scheduler = Scheduler.find(params[:scheduler_id])
    @log = execute_action(@scheduler)
    render partial: "visual_test"
  end

  action_auth_level :update, :instructor
  def update
    @scheduler = Scheduler.find_by(id: params[:id])
    action_path = Rails.root.join(scheduler_params[:action]).to_path
    # Check if the action file exists, is readable, and compiles
    if validate_compile_action_file(action_path)
      previous_state = @scheduler.attributes
      if @scheduler.update(scheduler_params)
        # Ensure visual run is successful
        if run_visual_scheduler(@scheduler)
          flash[:success] = "Scheduler updated and executed successfully!"
          redirect_to(course_schedulers_path(@course)) and return
        else
          @scheduler.update(previous_state) # If error, revert to previous state.
          flash[:error] = "Scheduler update failed during execution. Reverted to previous state."
        end
      else
        flash[:error] = "Scheduler update failed! Please check your fields."
      end
    end
    redirect_to(edit_course_scheduler_path(@course, @scheduler))
  end

  action_auth_level :destroy, :instructor
  def destroy
    @scheduler = Scheduler.find_by(id: params[:id])
    if @scheduler&.destroy
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

  def set_manage_scheduler_breadcrumb
    return if @course.nil?

    @breadcrumbs << (view_context.link_to "Manage Schedulers", course_schedulers_path(@course))
  end

  def validate_compile_action_file(action_path)
    # Check if the action file exists and is readable
    unless File.exist?(action_path) && File.readable?(action_path)
      flash[:error] = "Scheduler update failed. Action file does not exist or is
        not readable at #{action_path}."
      return false
    end

    # compile action file to check for syntax errors
    begin
      RubyVM::InstructionSequence.compile(File.read(action_path))
    rescue SyntaxError => e
      flash[:error] = "Syntax error in action file: #{e.message}"
      return false
    rescue StandardError => e
      flash[:error] = "Error validating action file: #{e.message}"
      return false
    end

    true
  end

  def run_visual_scheduler(scheduler)
    log = execute_action(scheduler)
    # Ensure visual run is successful or return error
    if log.include?("Error")
      flash[:error] = "Scheduler execution failed."
      false
    else
      flash[:success] = "Scheduler executed successfully!"
      true
    end
  end

  def execute_action(scheduler)
    action_path = Rails.root.join(scheduler.action).to_path
    # https://stackoverflow.com/a/1076445
    read, write = IO.pipe
    log = "Executing #{action_path}\n"
    begin
      pid = fork do
        read.close
        mod_name = action_path
        fork_log = ""
        begin
          require mod_name
          output = Updater.update(scheduler.course)
          if output.respond_to?(:to_str)
            fork_log << "----- Script Output -----\n"
            fork_log << output
            fork_log << "\n----- End Script Output -----"
          end
        rescue ScriptError, StandardError => e
          fork_log << "----- Script Error Output -----\n"
          fork_log << "Error in '#{scheduler.course.name}' updater: #{e.message}\n"
          fork_log << e.backtrace.join("\n\t")
          fork_log << "\n---- End Script Error Output -----"
        end
        write.print fork_log
      end

      write.close
      result = read.read
      Process.wait2(pid)
      log << result
    rescue StandardError => e
      log << "----- Error Output -----\n"
      log << "Error during execution: #{e.message}\n"
      log << e.backtrace.join("\n\t")
      log << "\n---- End Error Output -----"
    end
    log << "\nCompleted running action."
    log
  end
end
