##
# Each Assessment can have a scoreboard, which is modified with this controller
#
class ScoreboardsController < ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb, only: [:edit]
  before_action :set_scoreboard, except: [:create]
  rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :create, :instructor
  def create
    @scoreboard = Scoreboard.new do |s|
      s.assessment_id = @assessment.id
      s.banner = ""
      s.colspec = ""
    end
    begin
      @scoreboard.save!
      flash[:info] = "Scoreboard Created"
    rescue ActiveRecord::RecordInvalid => invalid
      flash[:error] = "Unable to create scoreboard: " + invalid.message
    end
    redirect_to(action: :edit) && return
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
        next unless user.student?
        @grades[uid] = {}
        @grades[uid][:nickname] = user.nickname
        @grades[uid][:andrewID] = user.email
        @grades[uid][:fullName] = user.first_name + " " + user.last_name
        @grades[uid][:problems] = {}
      end
      if @grades[uid][:version] != row["version"]
        # MySQL returns a Time object, but SQLite returns a time-stamp string
        row["time"] = Time.parse(row["time"]) if row["time"].class != Time
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
      begin
        if @assessment.overwrites_method?(:createScoreboardEntry)
          grade[:entry] = @assessment.config_module.createScoreboardEntry(
            grade[:problems],
            grade[:autoresult])
        else
          grade[:entry] = createScoreboardEntry(
            grade[:problems],
            grade[:autoresult])
        end
      rescue StandardError => e
        # Screw 'em! usually this means the grader failed.
        grade[:entry] = {}
        # But, if this was an instructor, we want them to know about
        # this.
        if @cud.instructor?
          @errorMessage = "An error occurred while calling " \
            "createScoreboardEntry(#{grade[:problems].inspect},"\
            "#{grade[:autoresult]})"
          @error = e
          render([@course, @assessment]) && return
        end
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
    @sortedGrades = @grades.values.sort do |a, b|
      begin

        if @assessment.overwrites_method?(:scoreboardOrderSubmissions)
          @assessment.config_module.scoreboardOrderSubmissions(a, b)
        else
          scoreboardOrderSubmissions(a, b)
        end

      rescue StandardError => e
        if @cud.instructor?
          @errorMessage = "An error occurred while calling "\
            "scoreboardOrderSubmissions(#{a.inspect},"\
            "#{b.inspect})"
          @error = e
          render([@course, @assessment]) && return
        end
        0 # Just say they're equal!
      end
    end

    @colspec = nil
    unless @scoreboard.colspec.blank?
      # our scoreboard validations should ensure this will always work
      @colspec = ActiveSupport::JSON.decode(@scoreboard.colspec)["scoreboard"]
    end
  end

  action_auth_level :edit, :instructor
  def edit
    # Set the @column_summary instance variable for the view
    @column_summary = emitColSpec(@scoreboard.colspec)
  end

  action_auth_level :update, :instructor
  def update
    @scoreboard.update(scoreboard_params) ? flash[:notice] = "Saved!" : flash[:error] = @scoreboard.errors.full_messages.join('')
    redirect_to(action: :edit) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    if @scoreboard.destroy
      flash[:info] = "Destroyed!"
    else
      flash[:error] = "Unable to destroy scoreboard"
    end
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
    redirect_to([@course, @assessment]) if @scoreboard.nil?
  end

  def scoreboard_params
    params[:scoreboard].permit(:banner, :colspec)
  end

  # emitColSpec - Emits a text summary of a column specification string.
  def emitColSpec(colspec)
    return "Empty column specification" if colspec.blank?
    
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
      str += hash["asc"] ? " [asc]" : " [desc]" if i < 3
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
      for problem in @assessment.problems do
        total += scores[problem.name].to_f
      end

      # Now build the array of scores
      entry = []
      entry << total.round(1).to_s
      for problem in @assessment.problems do
        entry << scores[problem.name]
      end
      return entry
    end

    # At this point we have an autograded assessment with a
    # customized scoreboard. Extract the scoreboard entry
    # from the scoreboard array object in the JSON autoresult.
    begin
      parsed = ActiveSupport::JSON.decode(autoresult)
      fail if !parsed || !parsed["scoreboard"]
    rescue
      # If there is no autoresult for this student (typically
      # because their code did not compile or it segfaulted and
      # the intructor's autograder did not catch it) then
      # return a nicely formatted nil result.
      begin
        parsed = ActiveSupport::JSON.decode(@scoreboard.colspec)
        fail if !parsed || !parsed["scoreboard"]
        entry = []
        for item in parsed["scoreboard"] do
          entry << "-"
        end
        return entry
      rescue
        # Give up and bail
        return ["-"]
      end
    end

    # Found a valid scoreboard array, so simply return it. If we
    # wanted to be really careful, we would verify that the size
    # was the same size as the column specification.
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
      aSum = 0; bSum = 0
      a[:problems].keys.each do |key|
        aSum += a[:problems][key].to_f
      end
      b[:problems].keys.each do |key|
        bSum += b[:problems][key].to_f
      end
      if (bSum != aSum)
        bSum <=> aSum # descending
      else
        a[:time] <=> b[:time]
      end

      # In this case, we have an autograded lab for which the
      # instructor has created a custom column specification.  By
      # default, we sort the first three columns from left to right
      # in descending order. Lab authors can modify the default
      # direction with the "asc" key in the column spec.
    else
      a0 = a[:entry][0].to_f
      a1 = a[:entry][1].to_f
      a2 = a[:entry][2].to_f
      b0 = b[:entry][0].to_f
      b1 = b[:entry][1].to_f
      b2 = b[:entry][2].to_f

      begin
        parsed = ActiveSupport::JSON.decode(@scoreboard.colspec)
      rescue
      end

      if a0 != b0
        if parsed && parsed["scoreboard"] &&
           parsed["scoreboard"].size > 0 &&
           parsed["scoreboard"][0]["asc"]
          a0 <=> b0 # ascending order
        else
          b0 <=> a0 # descending order
        end
      elsif a1 != b1
        if parsed && parsed["scoreboard"] &&
           parsed["scoreboard"].size > 1 &&
           parsed["scoreboard"][1]["asc"]
          a1 <=> b1 # ascending order
        else
          b1 <=> a1 # descending order
        end
      elsif a2 != b2
        if parsed && parsed["scoreboard"] &&
           parsed["scoreboard"].size > 2 &&
           parsed["scoreboard"][2]["asc"]
          a2 <=> b2 # ascending order
        else
          b2 <=> a2 # descending order
        end
      else
        a[:time] <=> b[:time] # ascending by submission time
      end
    end
  end
end
