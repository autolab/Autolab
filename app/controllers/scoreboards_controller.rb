##
# Each Assessment can have a scoreboard, which is modified with this controller
#
class ScoreboardsController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb, only: [:edit]
  before_action :set_scoreboard, except: [:create]

  action_auth_level :create, :instructor
  def create
    @scoreboard = Scoreboard.new do |s|
      s.assessment_id = @assessment.id
      s.banner = ""
      s.colspec = ""
    end
    flash[:info] = "Scoreboard Created" if @scoreboard.save
    redirect_to([:edit, @course, @assessment, :scoreboard]) && return
  end

  action_auth_level :show, :student
  def show
  end

  action_auth_level :edit, :instructor
  def edit
    # Set the @column_summary instance variable for the view
    @column_summary = emitColSpec(@scoreboard.colspec)
  end


  action_auth_level :update, :instructor
  def update
    # Update the scoreboard properties in the db
    colspec = params[:scoreboard_prop][:colspec]
    @scoreboard_prop = ScoreboardSetup.where(assessment_id: @assessment.id).first
    if @scoreboard_prop.update_attributes(scoreboard_prop_params)
      flash[:success] = "Updated scoreboard properties."
      redirect_to(action: "adminScoreboard") && return
    else
      flash[:error] = "Errors prevented the scoreboard properties from being saved."
    end

    flash[:info] = "Saved!" if @scoreboard.update(scoreboard_params)
    redirect_to([:edit, @course, @assessment, :scoreboard]) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    flash[:info] = "Destroyed!" if @scoreboard.destroy
    redirect_to([:edit, @course, @assessment]) && return
  end

  action_auth_level :help, :instructor
  def help
  end

private

  def set_assessment_breadcrumb
    @breadcrumbs << (view_context.link_to "Edit Assessment", [:edit, @course, @assessment])
  end

  def set_scoreboard
    @scoreboard = @assessment.scoreboard
  end
  
  def scoreboard_params
    params[:scoreboard].permit(:banner, :colspec)
  end

  # emitColSpec - Emits a text summary of a column specification string.
  def emitColSpec(colspec)
    return "Empty column specification" if colspec.nil?

    begin
      # Quote JSON keys and values if they are not already quoted
      quoted = colspec.gsub(/([a-zA-Z0-9]+):/, '"\1":').gsub(/:([a-zA-Z0-9]+)/, ':"\1"')
      parsed = ActiveSupport::JSON.decode(quoted)
    rescue StandardError => e
      return "Invalid column spec"
    end

    # If there is no column spec, then use the default scoreboard
    unless parsed
      str = "TOTAL [desc] "
      @assessment.problems.each do |problem|
        str += "| #{problem.name.to_s.upcase}"
      end
      return str
    end

    # In this case there is a valid colspec
    first = true
    i = 0
    parsed["scoreboard"].each do |hash|
      if first
        str = ""
        first = false
      else
        str += " | "
      end
      str += hash["hdr"].to_s.upcase
      if i < 3
        str += hash["asc"] ? " [asc]" : " [desc]"
      end
      i += 1
    end
    str
  end

end
