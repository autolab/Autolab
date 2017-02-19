class Api::V1::AssessmentsController < Api::V1::BaseApiController

  def index
    asmts = @course.assessments.ordered
    allowed = [:name, :display_name, :description, :start_at, :due_at, :end_at, :updated_at, :max_grace_days, :handout, :writeup, :max_submissions, :disable_handins, :category_name, :group_size, :has_scoreboard]
    if @cud.student?
      asmts = asmts.released
    else
      allowed += [:visible_at, :grading_deadline]
    end

    results = []
    asmts.each do |asmt|
      result = asmt.attributes.symbolize_keys
      result.merge!(:has_scoreboard => asmt.has_scoreboard?)
      results << result
    end

    respond_with results, only: allowed
  end

end