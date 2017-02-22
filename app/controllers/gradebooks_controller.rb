require "association_cache"
require "csv"
require "statistics"
require "utilities"

class GradebooksController < ApplicationController
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end
  action_auth_level :show, :student
  def show
    if @cud.instructor?
      redirect_to action: :view
    elsif @cud.course_assistant?
      redirect_to action: :view, section: @cud.section
    else
      redirect_to action: :student
    end
  end

  action_auth_level :view, :course_assistant
  def view
    @matrix = GradeMatrix.new @course, @cud
    @section = params[:section]

    permission = @cud.has_auth_level? :instructor
    @options = {
      linkify_andrew_ids: permission,
      render_excused_grade_type: permission,
      render_zeroed_grade_type: permission,
      show_actions: permission
    }

    unless @cud.has_auth_level?(:instructor) || @section == @cud.section
      flash[:error] = "You can't view other section gradebooks."
      redirect_to([@course]) && return
    end
  end

  action_auth_level :student, :student
  def student
    @_cud = params[:id] ?
              CourseUserDatum.find_by_id(params[:id]) : @cud

    if @_cud.nil?
      flash[:error] = "Can't find requested user course data."
      redirect_to(course_course_user_datum_gradebook_path) && return
    end

    unless @cud == @_cud || (@cud.instructor? && @cud.course == @_cud.course)
      if (@cud != @_cud)
        flash[:error] = "You can't view other students' gradebooks."
      else
        flash[:error] = "You can't view other classes' gradebooks."
      end
      redirect_to(course_course_user_datum_gradebook_path) && return
    end

    @categories_sorted = @course.assessment_categories
  end

  action_auth_level :csv, :instructor
  def csv
    @matrix = GradeMatrix.new @course, @cud

    csv = render_to_string layout: false
    send_data csv, filename: "#{@course.name}.csv"
  end

  action_auth_level :invalidate, :instructor
  def invalidate
    GradeMatrix.invalidate @course
    redirect_to action: :show
  end

  action_auth_level :statistics, :instructor
  def statistics
    matrix = GradeMatrix.new @course, @cud
    cols = {}

    # extract assessment final scores
    @course.assessments.each do |asmt|
      next unless matrix.has_assessment? asmt.id

      cells = matrix.cells_for_assessment asmt.id
      final_scores = cells.map { |c| c["final_score"] }
      cols[asmt.name] = final_scores
    end

    # category averages
    @course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat

      cols["#{cat} Average"] = matrix.averages_for_category cat
    end

    # course averages
    cols["Course Average"] = matrix.course_averages

    # calculate statistics
    @course_stats = {}
    stat = Statistics.new
    cols.each do |key, value|
      @course_stats[key] = stat.stats(value)
    end
  end

  action_auth_level :bulkRelease, :instructor
  def bulkRelease
    for assessment in @course.assessments do
      for problem in assessment.problems do
        scores = problem.scores.where(released: false)
        for score in scores do
          score.released = true
          score.save
        end
      end
    end
    redirect_to course_course_user_datum_gradebook_path(@course, @cud)
  end
end
