require "association_cache"
require "csv"
require "statistics"
require "utilities"

class GradebooksController < ApplicationController
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

    return if @cud.has_auth_level?(:instructor) || @section == @cud.section

    flash[:error] = "You can't view other section gradebooks."
    redirect_to([@course]) && return
  end

  action_auth_level :student, :student
  def student
    @_cud = if params[:id]
              CourseUserDatum.find_by(id: params[:id])
            else
              @cud
            end

    if @_cud.nil?
      flash[:error] = "Can't find requested user course data."
      redirect_to(course_course_user_datum_gradebook_path) && return
    end

    unless @cud == @_cud || (@cud.instructor? && @cud.course == @_cud.course)
      flash[:error] = if @cud != @_cud
                        "You can't view other students' gradebooks."
                      else
                        "You can't view other classes' gradebooks."
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

  action_auth_level :bulk_release, :instructor
  def bulk_release
    @course.assessments.each do |assessment|
      assessment.problems.each do |problem|
        scores = problem.scores.where(released: false)
        scores.each do |score|
          score.released = true
          score.save
        end
      end
    end
    redirect_to course_course_user_datum_gradebook_path(@course, @cud)
  end
end
