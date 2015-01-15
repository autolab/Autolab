require 'csv'
require 'utilities'

module AssessmentGrading
 
  # Export all scores for an assessment for all students as CSV
  def bulkExport
    # generate CSV
    csv = render_to_string :layout => false

    # send CSV file
    timestamp = Time.now.strftime "%Y%m%d%H%M"
    file_name = "#{@course.name}_#{@assessment.name}_#{timestamp}.csv"
    send_data csv, :filename => file_name
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
        redirect_to :controller => :home, :action => :error and return
      end

      # get CSV
      csv_file = params[:upload][:file]
      if csv_file
        @csv = csv_file.read
      else
        flash[:error] = "You need to choose a CSV file to upload."
        redirect_to :action => :bulkGrade and return
      end

      # process CSV
      success, entries = parse_csv @csv, @data_type
      if success
        @entries = entries
        @valid_entries = valid_entries? entries
      else
        redirect_to :action => :bulkGrade and return
      end
    end
  end

  # part 2: confirming a CSV upload and saving data
  def bulkGrade_complete
    redirect_to :action => :bulkGrade and return unless request.post?

    # retrieve entries CSV from hidden field in form
    csv = params[:confirm][:bulkGrade_csv]
    data_type = params[:confirm][:bulkGrade_data_type].to_sym
    unless csv && data_type
      flash[:error] = "Please try again."
      redirect_to :action => :bulkGrade and return
    end

    success, @entries = parse_csv csv, data_type
    if !success
      flash[:error] = "bulkGrade_complete: invalid csv returned from client"
      redirect_to :controller => :home, :action => :error and return
    elsif !valid_entries?(@entries)
      flash[:error] = "bulkGrade_complete: invalid entries returned from client"
      redirect_to :controller => :home, :action => :error and return
    end

    # save data
    unless save_entries @entries, data_type
      redirect_to :controller => :home, :action => :error and return
    end
  end

private
  def valid_entries? entries
    entries.reduce true do |acc, entry|
      acc && valid_entry?(entry)
    end
  end

  def valid_entry? entry
    entry.values.reduce true do |acc, v|
      acc && (case v
      when Hash
        !v.include?(:error) && valid_entry?(v)
      else
        true
      end)
    end
  end

  # TODO
  # def save_entries entries, data_type
#     asmt = @assessment
# 
#     begin 
#       User.transaction do
#         entries.each do |entry|
#           user = asmt.course.users.find_by_andrewID entry[:andrew_ID]
# 
#           aud = AssessmentUserDatum.get asmt.id, user.id
#           if entry[:grade_type]
#             aud.grade_type = AssessmentUserDatum::GRADE_TYPE_MAP[entry[:grade_type]]
#             aud.save!
#           end
#   
#           unless sub = aud.latest_submission
#             sub = asmt.submissions.build(
#               :user_id => user.id,
#               :assessment_id => asmt.id,
#               :submitted_by_id => @user.id
#             )
#             sub.save!
#           end
# 
#           entry[:data].each do |problem_name, datum|
#             next unless datum
# 
#             problem = asmt.problems.find_by_name problem_name
# 
#             score = sub.scores.find_by_problem_id problem.id
#             unless score
#               score = sub.scores.build(
#                 :grader_id => @user.id,
#                 :problem_id => problem.id
#               )
#             end
# 
#             case data_type 
#             when :scores
#               score.score = datum
#             when :feedback
#               score.feedback = datum.gsub("\\n", "\n").gsub("\\t", "\t")
#             end
# 
#             updateScore user.id, score
#           end
# 
#         end # entries.each
#       end # User.transaction
# 
#       true
#     rescue => e
#       flash[:error] = "An error occurred: #{e}"
# 
#       false
#     end
#   end
  # 
  # def parse_csv csv, data_type
  #   # inputs for parse_csv_row
  #   problems = @assessment.problems
  #   andrew_IDs = Set.new(@course.users.map &:andrewID)
  # 
  #   # process CSV
  #   entries = []
  #   begin
  #     CSV.parse(csv, { :skip_blanks => true }) do |row|
  #       entries << parse_csv_row(row, data_type, problems, andrew_IDs)
  #     end
  #   rescue CSV::MalformedCSVError => e
  #     flash[:error] = "Failed to parse CSV -- make sure the grades " +
  #                     "are formatted correctly: <pre>#{e.to_s}</pre>"
  #     return false, []
  #   end
  # 
  #   return true, entries
  # end
  # 
  # def parse_csv_row row, kind, problems, andrew_IDs
  #   row = row.dup
  # 
  #   andrew_ID = row.shift.to_s
  #   data = row.shift problems.count
  #   grade_type = row.shift.to_s
  # 
  #   # to be returned
  #   processed = {}
  #   processed[:extra_cells] = row if row.length > 0 # currently unused
  # 
  #   # andrew ID
  #   processed[:andrew_ID] = if andrew_ID.blank?
  #     { :error => nil }
  #   elsif andrew_IDs.include? andrew_ID
  #     andrew_ID
  #   else
  #     { :error => andrew_ID }
  #   end
  # 
  #   # data
  #   data.map! do |datum|
  #     if datum.blank?
  #       nil
  #     else
  #       case kind
  #       when :scores
  #         Float(datum) rescue({ :error => datum })
  #       when :feedback
  #         datum
  #       end
  #     end
  #   end
  # 
  #   # pad data with nil until there are problems.count elements
  #   data.fill nil, data.length, problems.count - data.length
  # 
  #   processed[:data] = {}
  #   problems.each_with_index { |problem, i| processed[:data][problem.name] = data[i] }
  # 
  #   # grade type
  #   processed[:grade_type] = if grade_type.blank?
  #     nil
  #   elsif AssessmentUserDatum::GRADE_TYPE_MAP.has_key? grade_type.to_sym
  #     grade_type.to_sym
  #   else
  #     { :error => grade_type }
  #   end
  # 
  #   processed
  # end

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
    score.score = params[:score].to_i

    updateScore(score.submission.course_user_datum_id, score)

    render :text => score.score

  # see http://stackoverflow.com/questions/6163125/duplicate-records-created-by-find-or-create-by
  # and http://barelyenough.org/blog/2007/11/activerecord-race-conditions/
  # and http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
  rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => error
    @retries_left = @retries_left || 2
    retry unless ((@retries_left -= 1) < 0)
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
    score.feedback = params[:feedback];
    score.released = params[:released];

    updateScore(score.submission.course_user_datum_id, score)

    render :text => score.id

  # see http://stackoverflow.com/questions/6163125/duplicate-records-created-by-find-or-create-by
  # and http://barelyenough.org/blog/2007/11/activerecord-race-conditions/
  # and http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
  rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => error
    @retries_left = @retries_left || 2
    retry unless ((@retries_left -= 1) < 0)
    raise error
  end
  
  def submission_popover
    render :partial => "popover", :locals => { :s => Submission.find(params[:submission_id].to_i) }
  end
  
  def score_grader_info
    grader = Score.find(params[:id]).grader
    if grader
      render :text => "#{grader.first_name} #{grader.last_name} (#{grader.email})"
    else
      render :nothing => true
    end
  end

  def viewGradesheet
    load_gradesheet_data
  end

  def quickGetTotal
    return unless params[:submission_id]

    # get submission and problem IDs
    sub_id = params[:submission_id].to_i

    render :text => Submission.find(sub_id).final_score(@cud)
  end

  def statistics
    return unless load_course_config
    latest_submissions = @assessment.submissions.latest.includes(:scores, :course_user_datum)

    # Each value other than for :all is of the form
    # [[<group>, {:mean, :median, :max, :min, :stddev}]...]
    # for each group. :all has just the hash.
    @statistics = {}

    # Rather than special case this, we just index into the result.
    by_assessment = latest_submissions.group_by { |s| s.assessment.name }
    all_grouping = stats_for_grouping(by_assessment)[0]
    if all_grouping.nil?
      @statistics[:all] = []
    else
      @statistics[:all] = all_grouping[1]
    end
    
    by_lecture = latest_submissions.group_by { |s| s.course_user_datum.lecture }
    @statistics[:lecture] = stats_for_grouping(by_lecture)

    by_section = latest_submissions.group_by { |s| s.course_user_datum.section }
    @statistics[:section] = stats_for_grouping(by_section)

    by_school = latest_submissions.group_by { |s| s.course_user_datum.school }
    @statistics[:school] = stats_for_grouping(by_school)

    by_major = latest_submissions.group_by { |s| s.course_user_datum.major }
    @statistics[:major] = stats_for_grouping(by_major)

    by_year = latest_submissions.group_by { |s| s.course_user_datum.year }
    @statistics[:year] = stats_for_grouping(by_year)

    @statistics[:grader] = stats_for_grader(latest_submissions)
  end

  # TODO
  # def autoCompleteAndrewID
  #   if !params[:andrewID] then 
  #     render :text=>"" and return
  #   end
  #   if (params[:spellSuggest].to_s() == "true") then 
  #     # Implementation of a super simple Spell Correction Algorithm
  #     # Written by Hunter Pitelka while waiting for Oracle to install. 
  #     dictionary = @course.users.all
  #     search = params[:andrewID]
  #     distances = []
  #     for user in dictionary do
  #       word = user.andrewID
  #       distance = 0
  #       for i in 0..[search.length,word.length].max do 
  #         # Letters that match perfectly earn 2 points
  #         distance += (search[i] == word[i]) ? 2 : 0 
  # 
  #         # Letters that match to the left or right earn 1 point
  #         distance += (search[i] == word[i+1]) ? 1 : 0
  #         distance += (search[i] == word[i-1]) ? 1 : 0
  #       end
  #       distances << {:distance=>distance,:word=>user}
  #     end
  #     distances.sort!{ |a,b| 
  #       a[:distance] <=> b[:distance] 
  #     }
  #     @users = distances[-5..-1].reverse
  #   else
  #     params[:andrewID] += "%"
  #     @users = @course.users.where(["andrewID LIKE ?",params[:andrewID]]).order("andrewID ASC")
  #   end
  #   render :partial=>"autoCompleteAndrewID", :layout=>false and return
  # end
  # 
  # def bulkFeedback
  #   if not request.post? then
  #     return
  #   end
  # 
  #   if params[:post] == "grades" then
  #     # Get a list of the valid score ID's for fast(er) validation
  #     dbResult = ActiveRecord::Base.connection.select_values(
  #       "SELECT scores.id
  #       FROM scores,submissions 
  #       WHERE scores.submission_id = submissions.id
  #       AND submissions.assessment_id = #{@assessment.id}")
  #     validScoreIds = dbResult.map { |i| i.to_i }
  #     params["score"].each_key { |key| 
  #       unless validScoreIds.include?(key.to_i()) then
  #         flash[:error] = "Invalid Score ID #{key}"
  #         redirect_to :action=>"bulkFeedback" and return
  #       end
  #     }
  # 
  #     params["score"].each_pair { |scoreId,value| 
  #       id = scoreId.to_i()
  #       score = Score.find(id)
  #       score.score = value
  #       score.save()
  #     }
  #     flash[:success] = "Successfully stored " + 
  #       params["score"].length.to_s + " scores!"
  #     redirect_to :action=>"index" and return
  #   else
  #     #Figure out which problems we're saving this for.
  #     @problem = @assessment.problems.find(params[:problem])
  #     if @problem.nil? then
  #       flash[:error] = "Invalid Problem id #{params[:problem]}!"
  #       redirect_to :action=>"bulkFeedback" and return
  #     end
  # 
  #     archive = params[:file]
  #     if (archive.nil?) then
  #       flash[:error] = "You must specify a file to upload!"
  #       redirect_to :action=>"bulkFeedback" and return
  #     end
  # 
  #     require 'libarchive'
  #     errors = []
  #     @uploadedStudents = []
  #     begin
  #     Archive.read_open_memory(archive.read()) do |ar|
  #       while entry = ar.next_header()  do
  #         filename = entry.pathname()
  # 
  #         #Figure out the andrewID
  #         andrewID = filename.split("_")[0]
  #         student = @course.users.where(:andrewID => andrewID).first
  #         if student.nil? then
  #           errors << "Invalid andrewID:#{andrewID} " + 
  #             "from file #{filename}"
  #           next
  #         end
  # 
  #         # Get the submission entry
  #         submission = @assessment.submissions.where(:user_id=>student.id).order("version DESC").first
  #         if submission.nil? then
  #           errors << "Student " + 
  #             student.full_name_with_email +
  #             " has no submission for this assignment!"
  #           next
  #         end
  # 
  #         # Get the score entry
  #         score = submission.scores.find_with_feedback(:first,
  #           :conditions => { :problem_id => @problem.id,
  #             :submission_id=>submission.id}
  #         )
  #         if score.nil? then 
  #           #That's okay, let's create one. 
  #           score = Score.new(:submission_id=>submission.id,
  #             :problem_id=>@problem.id,:released=>false)
  #         end
  # 
  #         score.grader_id = @user.id
  # 
  #         #Upload this file as a feedback file. 
  #         score.feedback_file_name = filename
  # #       score.feedback_file_type =
  #         score.feedback_file = ar.read_data()  
  #         score.save()
  # 
  #         @uploadedStudents << {:user=>student,
  #           :submission=>submission,
  #           :score=>score,
  #           :feedback=>filename}
  #       end
  #     end
  #     rescue Archive::Error 
  #       flash[:error] = "Unsupported Archive File: " + 
  #         " #{archive.original_filename}"
  #       redirect_to :action=>"bulkFeedback" and return
  #     end
  # 
  #     @uploadedStudents.sort! { |a,b| 
  #       a[:user].andrewID <=> b[:user].andrewID 
  #     }
  # 
  #     if @uploadedStudents.size == 0 then 
  #       flash[:error] = "You uploaded an empty Archive File"  
  #       redirect_to :action=>"bulkFeedback" and return
  #     end
  # 
  #     if errors.size > 0 then
  #       flash[:error] = "Errors occurred while processing" +
  #         " your request<br>" + errors.join("<br>")
  #       redirect_to :action=>"bulkFeedback" and return
  #     end
  # 
  #   end
  # end

private
  def load_course_config
    course = @course.name.gsub(/[^A-Za-z0-9]/,'')
    begin 
      load(File.join(Rails.root,"courseConfig",
        "#{course}.rb"))
      eval("extend(Course#{course.camelize})")
    rescue Exception
      render(:text=>"Error loading your course's grading " +
        "configuration file.  Please go <a href='/#{@course.name}/"+
        "admin/reload'>here</a> to reload the file, and try again") and
      return false
    end
    return true
  end

  def stats_for_grouping(grouping)
    result = []
    problem_id_to_name = @assessment.problem_id_to_name
    stats = Statistics.new

    # There can be null keys here because some of the
    # values we group by are nullable in the DB. We
    # shouldn't show those.
    grouping.keys.compact.sort.each do |group|
      problem_scores = {}

      @assessment.problems.each do |problem|
        problem_scores[problem.id] = []
      end
      problem_scores[:total] = []

      grouping[group].each do |submission|
        next unless submission.course_user_datum.student?
        next unless submission.special_type == Submission::NORMAL

        submission.scores.each do |score|
          problem_scores[score.problem_id] << score.score
        end

        problem_scores[:total] << submission.final_score(@cud)
      end

      # Need the problems to be in the right order.
      problem_stats = []
      @assessment.problems.each do |problem|
        problem_stats << [problem.name, stats.stats(problem_scores[problem.id])]
      end
      problem_stats << ['Total', stats.stats(problem_scores[:total])]

      result << [group, problem_stats]
    end
    return result
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
        if grader_scores.has_key? score.grader_id
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
        return autograder
      else
        return User.find(i)
      end
    end
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
    return result
  end

  # TODO
  def load_gradesheet_data
    @start = Time.now()
    id = @assessment.id
  
    # section filter
    o = params[:section] ? {
      :conditions => { :assessment_id => id, :users => { :section => @user.section } },
      :joins => "INNER JOIN users ON submissions.user_id = users.id" # hash doesn't work, Rails = stupid
    } : {
      :conditions => { :assessment_id => id }
    }
  
    # currently loads *all* assessment AUDs, scores in spite of the section filter
    # but that's okay, it only takes a couple 10ms
    cache = AssociationCache.new(@course) { |_|
      _.load_course_user_data
      _.load_auds
      _.load_latest_submissions o
      _.load_latest_submission_scores({ :conditions => { :submissions => { :assessment_id => id } } })
      _.load_assessments
    }
  
    @assessment = cache.assessments[@assessment.id]
    @submissions = cache.latest_submissions.values
  end
end
