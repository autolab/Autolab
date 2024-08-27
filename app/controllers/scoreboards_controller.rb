##
# Each Assessment can have a scoreboard, which is modified with this controller
#
class ScoreboardsController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb
  before_action :set_edit_assessment_breadcrumb, only: [:edit]
  before_action :set_scoreboard, except: [:create]

  action_auth_level :create, :instructor
  def create
    @scoreboard = Scoreboard.new do |s|
      s.assessment_id = @assessment.id
      s.banner = ""
      s.colspec = ""
    end
    begin
      @scoreboard.save!
      flash[:success] = "Created scoreboard successfully."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Unable to create scoreboard: #{e.message}"
    end
    redirect_to(edit_course_assessment_scoreboard_path(@course, @assessment))
  end

  action_auth_level :show, :student
  def show
    # It turns out that it's faster to just get everything and let the
    # view handle it
    problemQuery = "SELECT scores.score AS score,
        submissions.version AS version,
        submissions.created_at AS time,
        submissions.autoresult AS autoresult,
        problems.name AS problem_name,
        submissions.course_user_datum_id AS course_user_datum_id
        FROM scores,submissions,problems
        WHERE submissions.assessment_id=#{@assessment.id}
        AND submissions.id = scores.submission_id
        AND problems.id = scores.problem_id
        ORDER BY submissions.created_at ASC"
    result = ActiveRecord::Base.connection.select_all(problemQuery)
    @grades = {}
    result.each do |row|
      uid = row["course_user_datum_id"].to_i
      unless @grades.key?(uid)
        user = @course.course_user_data.find(uid)
        next unless user.student? || @scoreboard.include_instructors

        @grades[uid] = {}
        @grades[uid][:nickname] = user.nickname
        @grades[uid][:andrewID] = user.email
        @grades[uid][:fullName] = user.full_name
        @grades[uid][:problems] = {}
      end
      if @grades[uid][:version] != row["version"]
        # MySQL returns a Time object, but SQLite returns a time-stamp string
        row["time"] = Time.zone.parse(row["time"]) if row["time"].class != Time
        @grades[uid][:time] = row["time"].in_time_zone
        @grades[uid][:version] = row["version"].to_i
        @grades[uid][:autoresult] = row["autoresult"]
      end
      @grades[uid][:problems][row["problem_name"]] = row["score"].to_f.round(1)
    end

    # Build the html for the scoreboard header
    if @assessment.overwrites_method?(:scoreboardHeader)
      @config_header = @assessment.config_module.scoreboardHeader
    end

    # Build the scoreboard entries for each student
    @grades.values.each do |grade|
      grade[:entry] = if @assessment.overwrites_method?(:createScoreboardEntry)
                        @assessment.config_module.createScoreboardEntry(
                          grade[:problems],
                          grade[:autoresult]
                        )
                      else
                        createScoreboardEntry(
                          grade[:problems],
                          grade[:autoresult]
                        )
                      end
    rescue StandardError => e
      # the scoreboard autoresult wasn't correctly formatted
      # so we just return an empty array, which will be handled
      # by the #show view code
      grade[:entry] = []

      if @cud.instructor?
        # not using flash because could be too large of a message to pass
        @errorMessage = "An error occurred while calling " \
          "createScoreboardEntry(#{grade[:problems].inspect},\n"\
          "#{grade[:autoresult]})"
        @error = e
        Rails.logger.error("Scoreboard error in #{@course.name}/#{@assessment.name}: #{@error}")
      end
    end

    # We want to sort @grades.values instead of just @grades because @grades
    # is a hash, and we only care about the values. This is also why we
    # included the :nickname and :andrewID in the hash instead of looking
    # them up based on the uid index. See
    # http://greatwhite.ics.cs.cmu.edu/rubydoc/ruby/classes/Hash.html#M001122
    # for more information.

    # Catch errors along the way. An instructor will get the errors, a
    # student will simply see an unsorted scoreboard.
    begin
      @sortedGrades = @grades.values.sort do |a, b|
        # we add a default sort, in the case that the scoreboard entry could
        # not be generated correctly (which results in a empty array)
        if a[:entry].empty? || b[:entry].empty?
          b[:entry].length <=> a[:entry].length
        elsif @assessment.overwrites_method?(:scoreboardOrderSubmissions)
          begin
            @assessment.config_module.scoreboardOrderSubmissions(a, b)
          rescue StandardError => e
            if @cud.instructor?
              # not using flash because could be too large of a message to pass
              @errorMessage = "An error occurred while calling "\
                "custom hook scoreboardOrderSubmissions(#{a.inspect},\n"\
                "#{b.inspect})"
              @error = e
              Rails.logger.error("Custom scoreboard error in " \
                                   "#{@course.name}/#{@assessment.name}: #{@error}")
              render("scoreboards/edit") && return
            else
              flash[:error] =
                "The scoreboard cannot be viewed due to an error. Please contact your instructor."
              redirect_to(course_assessment_path(@course, @assessment)) && return
            end
          end
        else
          begin
            scoreboardOrderSubmissions(a, b)
          rescue StandardError => e
            # this is a catch all if sorting in general just doesn't work
            if @cud.instructor?
              # not using flash because could be too large of a message to pass
              @errorMessage = "An error occurred while calling "\
                "scoreboardOrderSubmissions(#{a.inspect},\n"\
                "#{b.inspect})"
              @error = e
              Rails.logger.error("scoreboard order error in #{@course.name}/#{@assessment.name}: " \
                                   "#{@error}")
              render("scoreboards/edit") && return
            else
              flash[:error] =
                "The scoreboard cannot be viewed due to an error. Please contact your instructor."
              redirect_to(course_assessment_path(@course, @assessment)) && return
            end
          end
        end
      end
    rescue ArgumentError => e
      if @cud.instructor?
        # not using flash because could be too large of a message to pass
        @errorMessage = "An error occurred while sorting "\
          "submissions. Please make sure your scoreboard results are returned " \
          "as an array of numbers. If you are using a custom scoreboard order, ensure your " \
          "hook is functioning correctly."
        @error = e
        Rails.logger.error("scoreboard error in #{@course.name}/#{@assessment.name}: #{@error}")
        render("scoreboards/edit") && return
      else
        flash[:error] =
          "The scoreboard cannot be viewed due to an error. Please contact your instructor."
        redirect_to(course_assessment_path(@course, @assessment)) && return
      end
    end

    @colspec = nil
    return unless @scoreboard.colspec.present?

    # our scoreboard validations should ensure this will always work
    @colspec = ActiveSupport::JSON.decode(@scoreboard.colspec)["scoreboard"]
  end

  action_auth_level :edit, :instructor
  def edit
    # Set the @column_summary instance variable for the view
    @column_summary = emitColSpec(@scoreboard.colspec)
  end

  action_auth_level :update, :instructor
  def update
    if @scoreboard.update(scoreboard_params)
      flash[:success] =
        "Scoreboard saved."
    else
      flash[:error] =
        @scoreboard.errors.full_messages.join("")
    end
    redirect_to(action: :edit) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    if @scoreboard.destroy
      flash[:success] = "Scoreboard successfully deleted."
    else
      flash[:error] = "Unable to destroy scoreboard."
    end
    redirect_to(edit_course_assessment_path(@course, @assessment))
  end

private

  def set_scoreboard
    @scoreboard = @assessment.scoreboard
    redirect_to(course_assessment_path(@course, @assessment)) if @scoreboard.nil?
  end

  def scoreboard_params
    params[:scoreboard].permit(:banner, :colspec, :include_instructors)
  end

  # emitColSpec - Emits a text summary of a column specification string.
  def emitColSpec(colspec)
    return "Empty column specification" if colspec.blank?

    begin
      # Quote JSON keys and values if they are not already quoted
      quoted = colspec.gsub(/([a-zA-Z0-9]+):/, '"\1":').gsub(/:([a-zA-Z0-9]+)/, ':"\1"')
      parsed = ActiveSupport::JSON.decode(quoted)
    rescue StandardError
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
      str += hash["asc"] ? " [asc]" : " [desc]"
      i += 1
    end
    str
  end

  #
  # createScoreboardEntry - Create a row in the scoreboard. If the
  # JSON autoresult string has a scoreboard array object, then use
  # that as the template, otherwise use the default, which is the
  # total score followed by the sum of the individual problem
  # scores.
  #
  # Lab authors can override this function in the lab config file.
  #
  def createScoreboardEntry(scores, autoresult)
    # If the assessment was not autograded or the scoreboard was
    # not customized, then simply return the list of problem
    # scores and their total.
    if !autoresult ||
       !@scoreboard ||
       !@scoreboard.colspec ||
       @scoreboard.colspec.blank?

      # First we need to get the total score
      total = 0.0
      @assessment.problems.each do |problem|
        total += scores[problem.name].to_f
      end

      # Now build the array of scores
      entry = []
      entry << total.round(1).to_s
      @assessment.problems.each do |problem|
        entry << scores[problem.name]
      end
      return entry
    end

    # At this point we have an autograded assessment with a
    # customized scoreboard. Extract the scoreboard entry
    # from the scoreboard array object in the JSON autoresult.

    parsed = ActiveSupport::JSON.decode(autoresult)

    # ensure that the parsed result is a hash with scoreboard field, where scoreboard is an array
    if !parsed || !parsed.is_a?(Hash) || !parsed["scoreboard"] ||
       !parsed["scoreboard"].is_a?(Array)
      # If there is no autoresult for this student (typically
      # because their code did not compile or it segfaulted and
      # the instructor's autograder did not catch it) then
      # raise an error, will be handled by caller
      if @cud.instructor?
        (flash.now[:error] = "Error parsing scoreboard for autograded assessment: " \
          "scoreboard result is not an array. Please ensure that the autograder returns " \
          "scoreboard results as an array.")
      end
      Rails.logger.error("Scoreboard error in #{@course.name}/#{@assessment.name}: " \
                           "Scoreboard result is not an array")
      raise StandardError
    end

    parsed["scoreboard"]
  end

  #
  # scoreboardOrderSubmissions - This function provides a "<=>"
  # functionality to sort rows on a scoreboard.  Row pairs are
  # passed in (a,b) and must return -1, 0, or 1 depending if a is
  # less than, equal to, or greater than b.  Parms a and b are of
  # form {:uid, :andrewID, :version, :time, :problems, :entry},
  # where problems is a hash that contains keys for each problem id
  # as well as for each problem name.  An entry is the array
  # returned from createScoreboardEntry.
  #
  # This function can be overwritten by the instructor in the lab
  # config file.
  #
  def scoreboardOrderSubmissions(a, b)
    # If the assessment is not autograded, or the instructor did
    # not create a custom column spec, then revert to the default,
    # which sorts by total problem, then by submission time.
    if !@assessment.has_autograder? ||
       !@scoreboard || @scoreboard.colspec.blank?
      aSum = 0
      bSum = 0
      a[:problems].keys.each do |key|
        aSum += a[:problems][key].to_f
      end
      b[:problems].keys.each do |key|
        bSum += b[:problems][key].to_f
      end
      if bSum != aSum
        bSum <=> aSum # descending
      else
        a[:time] <=> b[:time]
      end

      # In this case, we have an autograded lab for which the
      # instructor has created a custom column specification.  By
      # default, we sort the columns from left to right
      # in descending order. Lab authors can modify the default
      # direction with the "asc" key in the column spec.
    else
      begin
        parsed = ActiveSupport::JSON.decode(@scoreboard.colspec)
      rescue StandardError => e
        Rails.logger.error("Error in scoreboards controller updater: #{e.message}")
      end

      # Validations ensure that colspec is of the correct format
      parsed["scoreboard"].each_with_index do |v, i|
        ai = a[:entry][i].to_f
        bi = b[:entry][i].to_f
        next unless ai != bi
        return ai <=> bi if v["asc"] # ascending

        return bi <=> ai # descending otherwise
      end
      a[:time] <=> b[:time] # ascending by submission time to tiebreak
    end
  end
end
