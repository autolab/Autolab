require "csv"
require "utilities"

module AssessmentGrading
  # Export all scores for an assessment for all students as CSV
  def bulkExport
    # generate CSV
    csv = render_to_string layout: false

    # send CSV file
    timestamp = Time.now.strftime "%Y%m%d%H%M"
    file_name = "#{@course.name}_#{@assessment.name}_#{timestamp}.csv"
    send_data csv, filename: file_name
  end

  # Allows the user to upload multiple scores or comments from a CSV file
  def bulkGrade
    return unless request.post?

    # part 1: submitting a CSV for processing and returning errors in CSV
    if params[:upload]
      # get data type
      @data_type = params[:upload][:data_type].to_sym
      unless @data_type == :scores || @data_type == :feedback
        flash[:error] = "bulkGrade: invalid data_type received from client"
        redirect_to(action: :bulkGrade) && return
      end

      # get CSV
      csv_file = params[:upload][:file]
      if csv_file
        @csv = csv_file.read
      else
        flash[:error] = "You need to choose a CSV file to upload."
        redirect_to(action: :bulkGrade) && return
      end

      # process CSV
      success, entries = parse_csv @csv, @data_type
      if success
        @entries = entries
        @valid_entries = valid_entries? entries
      else
        redirect_to(action: :bulkGrade) && return
      end
    end
  end

  # part 2: confirming a CSV upload and saving data
  def bulkGrade_complete
    redirect_to(action: :bulkGrade) && return unless request.post?

    # retrieve entries CSV from hidden field in form
    csv = params[:confirm][:bulkGrade_csv]
    data_type = params[:confirm][:bulkGrade_data_type].to_sym
    unless csv && data_type
      flash[:error] = "Please try again."
      redirect_to(action: :bulkGrade) && return
    end

    success, @entries = parse_csv csv, data_type
    if !success
      flash[:error] = "bulkGrade_complete: invalid csv returned from client"
      redirect_to(action: :bulkGrade) && return
    elsif !valid_entries?(@entries)
      flash[:error] = "bulkGrade_complete: invalid entries returned from client"
      redirect_to(action: :bulkGrade) && return
    end

    # save data
    unless save_entries @entries, data_type
      flash[:error] = "Failed to Save Entries"
      redirect_to(action: :bulkGrade) && return
    end
  end

private

  def valid_entries?(entries)
    entries.reduce true do |acc, entry|
      acc && valid_entry?(entry)
    end
  end

  def valid_entry?(entry)
    entry.values.reduce true do |acc, v|
      acc && (case v
      when Hash
        !v.include?(:error) && valid_entry?(v)
      else
        true
      end)
    end
  end

  def save_entries(entries, data_type)
    asmt = @assessment

    begin
      User.transaction do
        entries.each do |entry|
          user = CourseUserDatum.joins(:user)
                 .find_by(users: { email: entry[:email] }, course: asmt.course)

          aud = AssessmentUserDatum.get asmt.id, user.id
          if entry[:grade_type]
            aud.grade_type = AssessmentUserDatum::GRADE_TYPE_MAP[entry[:grade_type]]
            aud.save!
          end

          unless sub = aud.latest_submission
            sub = asmt.submissions.create!(
              course_user_datum_id: user.id,
              assessment_id: asmt.id,
              submitted_by_id: @cud.id,
              created_at: [Time.current, asmt.due_at].min
            )
          end

          entry[:data].each do |problem_name, datum|
            next unless datum

            problem = asmt.problems.find_by_name problem_name

            score = sub.scores.find_by_problem_id problem.id
            unless score
              score = sub.scores.new(
                grader_id: @cud.id,
                problem_id: problem.id
              )
            end

            case data_type
            when :scores
              score.score = datum
            when :feedback
              score.feedback = datum.gsub("\\n", "\n").gsub("\\t", "\t")
            end

            updateScore user.id, score
          end
        end # entries.each
      end # User.transaction

      true
    rescue ActiveRecord::ActiveRecordError => e
      flash[:error] = "An error occurred: #{e}"

      false
    end
  end

  def parse_csv(csv, data_type)
    # inputs for parse_csv_row
    problems = @assessment.problems
    emails = Set.new(CourseUserDatum.joins(:user).where(course: @assessment.course).map &:email)

    # process CSV
    entries = []
    begin
      CSV.parse(csv, skip_blanks: true) do |row|
        entries << parse_csv_row(row, data_type, problems, emails)
      end
    rescue CSV::MalformedCSVError => e
      flash[:error] = "Failed to parse CSV -- make sure the grades " \
                      "are formatted correctly: <pre>#{e}</pre>"
      flash[:html_safe] = true
      return false, []
    end

    [true, entries]
  end

  def parse_csv_row(row, kind, problems, emails)
    row = row.dup

    email = row.shift.to_s
    data = row.shift problems.count
    grade_type = row.shift.to_s

    # to be returned
    processed = {}
    processed[:extra_cells] = row if row.length > 0 # currently unused

    # Checking that emails are valid
    processed[:email] = if email.blank?
                          { error: nil }
                        elsif emails.include? email
                          email
                        else
                          { error: email }
    end

    # data
    data.map! do |datum|
      if datum.blank?
        nil
      else
        case kind
        when :scores
          Float(datum) rescue({ error: datum })
        when :feedback
          datum
        end
      end
    end

    # pad data with nil until there are problems.count elements
    data.fill nil, data.length, problems.count - data.length

    processed[:data] = {}
    problems.each_with_index { |problem, i| processed[:data][problem.name] = data[i] }

    # grade type
    processed[:grade_type] = if grade_type.blank?
                               nil
                             elsif AssessmentUserDatum::GRADE_TYPE_MAP.key? grade_type.to_sym
                               grade_type.to_sym
                             else
                               { error: grade_type }
    end

    processed
  end

public

  def quickSetScore
    return unless request.post?
    return unless params[:submission_id]
    return unless params[:problem_id]

    # get submission and problem IDs
    sub_id = params[:submission_id].to_i
    prob_id = params[:problem_id].to_i

    # find existing score for this problem, if there's one
    # otherwise, create it
    score = Score.find_or_initialize_by_submission_id_and_problem_id(sub_id, prob_id)

    score.grader_id = @cud.id
    score.score = params[:score].to_f

    updateScore(score.submission.course_user_datum_id, score)

    render plain: score.score

  # see http://stackoverflow.com/questions/6163125/duplicate-records-created-by-find-or-create-by
  # and http://barelyenough.org/blog/2007/11/activerecord-race-conditions/
  # and http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
  rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => error
    @retries_left ||= 2
    retry unless (@retries_left -= 1) < 0
    raise error
  end

  def quickSetScoreDetails
    return unless request.post?
    return unless params[:submission_id]
    return unless params[:problem_id]
     # get submission and problem IDs
     sub_id = params[:submission_id].to_i
     prob_id = params[:problem_id].to_i


    # find existing score for this problem, if there's one
    # otherwise, create it
    score = Score.find_or_initialize_by_submission_id_and_problem_id(sub_id, prob_id)

    score.grader_id = @cud.id
    score.feedback = params[:feedback]
    score.released = params[:released]

    updateScore(score.submission.course_user_datum_id, score)

    render plain: score.id

  # see http://stackoverflow.com/questions/6163125/duplicate-records-created-by-find-or-create-by
  # and http://barelyenough.org/blog/2007/11/activerecord-race-conditions/
  # and http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => error
  @retries_left ||= 2
  retry unless (@retries_left -= 1) < 0
  raise error
end

  def submission_popover
    submission = Submission.find_by(id: params[:submission_id].to_i)
    if submission
      render partial: "popover", locals: { s: submission }
    else
      render plain: "Submission not found", status: :not_found
    end
  end

  def score_grader_info
    score = Score.find(params[:score_id])
    grader = (if score then score.grader else nil end)
    grader_info = ""
    if grader
      grader_info = grader.full_name_with_email
    end

    feedback = score.feedback
    response = { "grader" => grader_info, "feedback" => feedback, "score" => score.score }
    render json: response
  end

  def viewGradesheet
    load_gradesheet_data
  end

  def quickGetTotal
    return unless params[:submission_id]

    # get submission and problem IDs
    sub_id = params[:submission_id].to_i

    render plain: Submission.find(sub_id).final_score(@cud)
  end

  def statistics
    load_course_config
    latest_submissions = @assessment.submissions.latest_for_statistics.includes(:scores, :course_user_datum)
    #latest_submissions = @assessment.submissions.latest.includes(:scores, :course_user_datum)

    # Each value other than for :all is of the form
    # [[<group>, {:mean, :median, :max, :min, :stddev}]...]
    # for each group. :all has just the hash.
    @statistics = {}
    @scores = {}
    # Rather than special case this, we just index into the result.
    by_assessment = latest_submissions.group_by { |s| s.assessment.name }
    assessment_stats = stats_for_grouping(by_assessment)
    all_grouping = assessment_stats[assessment_stats.keys[0]]

    if all_grouping.nil?
      @statistics[:all] = []
      @scores[:all] = []
    else
      @statistics[:all] = all_grouping[:data]
      @scores[:all] = all_grouping[1]
    end

    by_course_number = latest_submissions.group_by { |s| s.course_user_datum.course_number }
    @statistics[:course_number] = stats_for_grouping(by_course_number)
    @scores[:course_number] = scores_for_grouping(by_course_number)

    by_lecture = latest_submissions.group_by { |s| s.course_user_datum.lecture }
    @statistics[:lecture] = stats_for_grouping(by_lecture)
    @scores[:lecture] = scores_for_grouping(by_lecture)

    by_section = latest_submissions.group_by { |s| s.course_user_datum.section }
    @statistics[:section] = stats_for_grouping(by_section)
    @scores[:section] = scores_for_grouping(by_section)

    by_school = latest_submissions.group_by { |s| s.course_user_datum.school }
    @statistics[:school] = stats_for_grouping(by_school)
    @scores[:school] = scores_for_grouping(by_school)

    by_major = latest_submissions.group_by { |s| s.course_user_datum.major }
    @statistics[:major] = stats_for_grouping(by_major)
    @scores[:major] = scores_for_grouping(by_major)

    by_year = latest_submissions.group_by { |s| s.course_user_datum.year }
    @statistics[:year] = stats_for_grouping(by_year)
    @scores[:year] = scores_for_grouping(by_year)
    @statistics[:grader] = stats_for_grader(latest_submissions)
  end

private

  def load_course_config
    course = @course.name.gsub(/[^A-Za-z0-9]/, "")
    begin
      load(File.join(Rails.root, "courseConfig",
                     "#{course}.rb"))
      eval("extend(Course#{course.camelize})")
    rescue LoadError, SyntaxError, NameError, NoMethodError => e
      @error = e
    end
  end

# Scores for grouping
  def scores_for_grouping(grouping)
    result = {}
    grouping.keys.compact.sort.each do |group|
      scoreresult = {}
      problem_scores = problem_scores_for_group(grouping, group)
      @assessment.problems.each do |problem|
        scoreresult[problem.name] = problem_scores[problem.id]
      end
      result[group] = scoreresult
    end
    result
  end

  # Problem scores for grouping
  def problem_scores_for_group(grouping, group)
    problem_scores = {}

    @assessment.problems.each do |problem|
      problem_scores[problem.id] = []
    end
    problem_scores[:total] = []

    grouping[group].each do |submission|
      next unless submission.course_user_datum.student?
      # TODO(jezimmer): Find a more permanent fix (see #529)
      #next unless submission.special_type == Submission::NORMAL

      submission.scores.each do |score|
        problem_scores[score.problem_id] << score.score
      end
      problem_scores[:total] << submission.final_score(@cud)
    end
    problem_scores
  end

# Stats for grouping
  def stats_for_grouping(grouping)
    result = {}
    problem_id_to_name = @assessment.problem_id_to_name
    stats = Statistics.new
    # There can be null keys here because some of the
    # values we group by are nullable in the DB. We
    # shouldn't show those.
    grouping.keys.compact.sort.each do |group|
      problem_scores = problem_scores_for_group(grouping,group)
      # Need the problems to be in the right order.
      problem_stats = {}
      # seems like we always index with 1
      @assessment.problems.each do |problem|
        problem_stats[problem.name] = stats.stats(problem_scores[problem.id])
      end
      problem_stats[:Total] = stats.stats(problem_scores[:total])
      result[group] = {}
      result[group][:data] = problem_stats
      result[group][:total_students] = problem_scores[:total].length
    end
    # raise result.inspect
    result
  end

  # This is different from all of the others because it doesn't
  # group by submission but by score (since multiple graders can
  # grade problems for a single submission).
  def stats_for_grader(submissions)
    result = []
    problem_id_to_name = @assessment.problem_id_to_name
    stats = Statistics.new

    grader_scores = {}
    submissions.each do |submission|
      next unless submission.special_type == Submission::NORMAL

      submission.scores.each do |score|
        next if score.grader_id.nil?
        if grader_scores.key? score.grader_id
          grader_scores[score.grader_id] << score
        else
          grader_scores[score.grader_id] = [score]
        end
      end
    end

    grader_ids = grader_scores.keys
    def find_user(i)
      if i == 0
        autograder = Hash["full_name", "Autograder",
                          "id", 0,
                          "full_name_with_email", "Autograder"]
        def autograder.method_missing(m)
          self[m.to_s]
        end

        autograder
      else
        @course.course_user_data.find(i)
      end
    end
    grader_ids.filter! { |i| i != -1 }
    graders = grader_ids.map(&method(:find_user))
    graders = graders.compact
    graders.sort! { |g1, g2| g1.full_name <=> g2.full_name }

    graders.each do |grader|
      scores = grader_scores[grader["id"]]

      problem_scores = {}
      @assessment.problems.each do |problem|
        problem_scores[problem.id] = []
      end

      scores.each do |score|
        problem_scores[score.problem_id] << score.score
      end

      problem_stats = []
      @assessment.problems.each do |problem|
        problem_stats << [problem.name, stats.stats(problem_scores[problem.id])]
      end

      result << [grader.full_name_with_email, problem_stats]
    end
    result
  end

  # TODO
  def load_gradesheet_data
    @start = Time.now
    id = @assessment.id

    # lecture/section filter
    o = params[:section] ? {
      conditions: { assessment_id: id, course_user_data: { lecture: @cud.lecture, section: @cud.section } }
    } : {
      conditions: { assessment_id: id }
    }

    # currently loads *all* assessment AUDs, scores in spite of the section filter
    # but that's okay, it only takes a couple 10ms
    cache = AssociationCache.new(@course) do |_|
      _.load_course_user_data
      _.load_auds
      _.load_latest_submissions o
      _.load_latest_submission_scores(conditions: { submissions: { assessment_id: id } })
      _.load_assessments
    end

    @assessment = cache.assessments[@assessment.id]
    @submissions = cache.latest_submissions.values
    @section_filter = params[:section]
  end
end
