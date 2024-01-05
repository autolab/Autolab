class WatchlistInstance < ApplicationRecord
  enum status: { pending: 0, contacted: 1, resolved: 2 }, _suffix: "watchlist"
  belongs_to :course_user_datum
  belongs_to :course
  belongs_to :risk_condition

  def self.get_instances_for_course(course_name)
    begin
      course_id = Course.find_by(name: course_name).id
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end
    WatchlistInstance.where(course_id:)
  end

  def self.get_num_pending_instance_for_course(course_name)
    begin
      course_id = Course.find_by(name: course_name).id
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end
    WatchlistInstance.where(course_id:,
                            status: :pending).distinct.count(:course_user_datum_id)
  end

  def self.refresh_instances_for_course(course_name, metrics_update = false)
    begin
      course = Course.find_by(name: course_name)
      category_blocklist = WatchlistConfiguration.get_category_blocklist_for_course(course_name)
      current_conditions = RiskCondition.get_current_for_course(course_name)
      current_instances = WatchlistInstance.where(course_id: course.id, archived: false)
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end

    # update!
    new_instances = []
    deprecated_instances = current_instances
    # now check current conditions
    if current_conditions.empty?
      # case 1: no current risk conditions exist
      # no-op
    else
      # case 2: current risk conditions exist

      # remove dropped students from watchlist
      filtered_instances = remove_dropped_students(course, current_instances)

      # take category blocklist into consideration
      new_instances, deprecated_instances = add_new_instances_for_conditions(
        current_conditions, course, category_blocklist, filtered_instances
      )
    end

    # archive previous watchlist instances
    if metrics_update
      deprecated_instances.each(&:archive_watchlist_instance)
    end

    new_instances
  end

  # Update the grace day usage condition watchlist instances for
  # each course user datum of a particular course
  #   This is called when:
  # - Grace days or late slack has been changed and the course record is saved
  # - invalidate_cgdubs are somehow incurred
  def self.update_course_gdu_watchlist_instances(course)
    parameters = RiskCondition.get_gdu_condition_for_course(course.name)
    return if parameters.nil?

    condition_id, grace_day_threshold, date = parameters

    old_instances = course.watchlist_instances.where(risk_condition_id: condition_id)

    new_instances = []
    course_user_data = course.students
    asmts_before_date = course.asmts_before_date(date)
    if asmts_before_date.count == 0
      ActiveRecord::Base.transaction do
        old_instances.each(&:archive_watchlist_instance)
      end
      return
    end
    course_user_data.each do |cud|
      new_instance = add_new_instance_for_cud_grace_day_usage(course, condition_id, cud,
                                                              asmts_before_date,
                                                              grace_day_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each(&:archive_watchlist_instance)

      new_instances.each do |inst|
        unless inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id}"\
                " in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  # Legacy code for callback based updates
  def self.update_cud_gdu_watchlist_instances(cud)
    # Ignore if this CUD is an instructor or CA or dropped
    return unless cud.student? && (cud.dropped == false || cud.dropped.nil?)

    # Get current grace day condition
    parameters = RiskCondition.get_gdu_condition_for_course(cud.course.name)
    return if parameters.nil?

    condition_id, grace_day_threshold, date = parameters

    # Archive old ones if there exist some
    old_instances = cud.watchlist_instances.where(risk_condition_id: condition_id)

    asmts_before_date = cud.course.asmts_before_date(date)
    if asmts_before_date.count == 0
      ActiveRecord::Base.transaction do
        old_instances.each(&:archive_watchlist_instance)
      end
      return
    end

    # Do the usual stuff as in refresh watchlist instances
    # Create a new instance if criteria are fit
    new_instance = add_new_instance_for_cud_grace_day_usage(cud.course, condition_id, cud,
                                                            asmts_before_date, grace_day_threshold)

    ActiveRecord::Base.transaction do
      old_instances.each(&:archive_watchlist_instance)

      if !new_instance.nil? && !new_instance.save
        raise "Fail to create new watchlist instance for CUD #{cud.id}"\
              " in course #{cud.course.name} with violation info #{new_instance.violation_info}"
      end
    end
  end

  # Legacy code for callback based updates
  def self.update_course_grade_watchlist_instances(course)
    parameters_grade_drop = RiskCondition.get_grade_drop_condition_for_course(course.name)
    parameters_low_grades = RiskCondition.get_low_grades_condition_for_course(course.name)
    return if parameters_grade_drop.nil? && parameters_low_grades.nil?

    old_instances = []
    new_instances = []
    course_user_data = course.students

    unless parameters_grade_drop.nil?
      grade_drop_condition_id, percentage_drop, consecutive_counts = parameters_grade_drop
      old_instances += course.watchlist_instances.where(risk_condition_id: grade_drop_condition_id)
      categories = course.assessment_categories
      asmt_arrs = categories.map { |category| course.assessments_with_category(category).ordered }
      asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts }

      course_user_data.each do |cud|
        new_instance = add_new_instance_for_cud_grade_drop(course, grade_drop_condition_id,
                                                           cud, asmt_arrs, consecutive_counts,
                                                           percentage_drop)
        new_instances << new_instance unless new_instance.nil?
      end
    end

    unless parameters_low_grades.nil?
      low_grades_condition_id, grade_threshold, count_threshold = parameters_low_grades
      old_instances += course.watchlist_instances.where(risk_condition_id: low_grades_condition_id)

      course_user_data.each do |cud|
        new_instance = add_new_instance_for_cud_low_grades(course, low_grades_condition_id,
                                                           cud, grade_threshold, count_threshold)
        new_instances << new_instance unless new_instance.nil?
      end
    end

    ActiveRecord::Base.transaction do
      old_instances.each(&:archive_watchlist_instance)

      new_instances.each do |inst|
        unless inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id}"\
                " in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  # Legacy code for callback based updates
  def self.update_individual_grade_watchlist_instances(cud)
    # Ignore if this CUD is an instructor or CA or dropped
    return unless cud.student? && (cud.dropped == false || cud.dropped.nil?)

    # Get current grade condition
    parameters_grade_drop = RiskCondition.get_grade_drop_condition_for_course(cud.course.name)
    parameters_low_grades = RiskCondition.get_low_grades_condition_for_course(cud.course.name)
    return if parameters_grade_drop.nil? && parameters_low_grades.nil?

    old_instances = []
    new_instances = []

    unless parameters_grade_drop.nil?
      grade_drop_condition_id, percentage_drop, consecutive_counts = parameters_grade_drop
      old_instances += cud.watchlist_instances.where(risk_condition_id: grade_drop_condition_id)
      categories = cud.course.assessment_categories
      asmt_arrs = categories.map do |category|
        cud.course.assessments_with_category(category).ordered
      end
      asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts }

      new_instance = add_new_instance_for_cud_grade_drop(cud.course, grade_drop_condition_id,
                                                         cud, asmt_arrs,
                                                         consecutive_counts, percentage_drop)
      new_instances << new_instance unless new_instance.nil?
    end

    unless parameters_low_grades.nil?
      low_grades_condition_id, grade_threshold, count_threshold = parameters_low_grades
      old_instances += cud.watchlist_instances.where(risk_condition_id: low_grades_condition_id)

      new_instance = add_new_instance_for_cud_low_grades(cud.course, low_grades_condition_id,
                                                         cud, grade_threshold, count_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each(&:archive_watchlist_instance)

      new_instances.each do |inst|
        unless inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id}"\
                " in course #{cud.course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  # Legacy code for callback based updates
  def self.update_course_no_submissions_watchlist_instances(course, course_assistant)
    parameters_no_submissions = RiskCondition.get_no_submissions_condition_for_course(course.name)
    return if parameters_no_submissions.nil?

    condition_id, no_submissions_threshold = parameters_no_submissions

    course_user_data = course.students
    unless course_assistant.nil?
      course_user_data = course_user_data.select { |cud| course_assistant.CA_of? cud }
    end

    old_instances = []
    new_instances = []

    course_user_data.each do |cud|
      old_instances += cud.watchlist_instances.where(risk_condition_id: condition_id)
      new_instance = add_new_instance_for_cud_no_submissions(course, condition_id, cud,
                                                             no_submissions_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each(&:archive_watchlist_instance)

      new_instances.each do |inst|
        unless inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id}"\
                " in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  def self.contact_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id: instance_ids)
    if instance_ids.length != instances.length
      found_instance_ids = instances.map(&:id)
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end
    ActiveRecord::Base.transaction do
      instances.each(&:contact_watchlist_instance)
    end
  end

  def self.resolve_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id: instance_ids)
    if instance_ids.length != instances.length
      found_instance_ids = instances.map(&:id)
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end

    ActiveRecord::Base.transaction do
      instances.each(&:resolve_watchlist_instance)
    end
  end

  def self.delete_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id: instance_ids)
    if instance_ids.length != instances.length
      found_instance_ids = instances.map(&:id)
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end

    ActiveRecord::Base.transaction do
      instances.each(&:delete_watchlist_instance)
    end
  end

  def archive_watchlist_instance
    if pending_watchlist?
      destroy
    else
      self.archived = true
      unless save
        raise "Failed to archive watchlist instance for user"\
              " #{course_user_datum.user_id} in course #{course.display_name}"
      end
    end
  end

  # rubocop:disable Style/GuardClause
  def contact_watchlist_instance
    if pending_watchlist?
      contacted_watchlist!

      raise "Failed to update watchlist instance #{id} to contacted" if !save
    else
      raise "Unable to contact a watchlist instance that is not pending #{id}"
    end
  end

  def resolve_watchlist_instance
    if pending_watchlist? || contacted_watchlist?
      resolved_watchlist!

      raise "Failed to update watchlist instance #{id} to resolved" if !save
    else
      raise "Unable to resolve a watchlist instance that is not pending or contacted #{id}"
    end
  end

  def delete_watchlist_instance
    if archived?
      destroy
    else
      raise "Unable to delete a watchlist instance that is not pending or archived #{id}"
    end
  end
  # rubocop:enable Style/GuardClause

  ##
  # Archives instances of dropped students
  #
  # Given course and current instances
  # archives instances where the student is no longer in the course
  # returns the remaining instances
  def self.remove_dropped_students(course, current_instances)
    dropped_cuds = CourseUserDatum.where(course_id: course.id, instructor: false,
                                         course_assistant: false, dropped: true).pluck(:id)
    current_instances.where(course_user_datum_id: dropped_cuds)
                     .find_each(&:archive_watchlist_instance)
    current_instances.where.not(course_user_datum_id: dropped_cuds)
  end

  def self.add_new_instances_for_conditions(conditions, course, category_blocklist,
                                            current_instances)
    new_instances = []

    # prevent dropped students from being considered
    course_user_data = CourseUserDatum.where(course_id: course.id, instructor: false,
                                             course_assistant: false, dropped: false)

    # new
    criteria2 = current_instances.where(status: :pending)

    # contacted or resolved
    criteria1 = current_instances - criteria2
    deprecated_instances = current_instances

    course_user_data.each do |cud|
      cur_instances = []
      conditions.each do |condition|
        case condition.condition_type

        when "grace_day_usage"
          grace_day_threshold = condition.parameters["grace_day_threshold"].to_i
          date = condition.parameters["date"]
          asmts_before_date = course.asmts_before_date(date)
          asmts_before_date = asmts_before_date.reject do |asmt|
            category_blocklist.include?(asmt.category_name)
          end

          if asmts_before_date.count == 0
            next # go to the next condition loop if there is no latest assessment
          end

          new_instance = add_new_instance_for_cud_grace_day_usage(course, condition.id, cud,
                                                                  asmts_before_date,
                                                                  grace_day_threshold)
          cur_instances << new_instance unless new_instance.nil?

        when "grade_drop"
          percentage_drop = condition.parameters["percentage_drop"].to_f
          consecutive_counts = condition.parameters["consecutive_counts"].to_i

          categories = course.assessment_categories - category_blocklist
          asmt_arrs = categories.map do |category|
            course.assessments_with_category(category).ordered
          end
          asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts }
          new_instance = add_new_instance_for_cud_grade_drop(course, condition.id, cud,
                                                             asmt_arrs, consecutive_counts,
                                                             percentage_drop)
          cur_instances << new_instance unless new_instance.nil?

        when "no_submissions"
          no_submissions_threshold = condition.parameters["no_submissions_threshold"].to_i

          new_instance = add_new_instance_for_cud_no_submissions(course, category_blocklist,
                                                                 condition.id, cud,
                                                                 no_submissions_threshold)
          cur_instances << new_instance unless new_instance.nil?

        when "low_grades"
          grade_threshold = condition.parameters["grade_threshold"].to_f
          count_threshold = condition.parameters["count_threshold"].to_i

          new_instance = add_new_instance_for_cud_low_grades(course, category_blocklist,
                                                             condition.id, cud,
                                                             grade_threshold, count_threshold)
          cur_instances << new_instance unless new_instance.nil?

        when "extension_requests"
          extension_count = condition.parameters["extension_count"].to_i
          new_instance = add_new_instance_for_cud_extension_requests(course, category_blocklist,
                                                                     condition.id, cud,
                                                                     extension_count)
          cur_instances << new_instance unless new_instance.nil?
        end
      end

      # check for duplication
      all_dup = true
      cur_instances.each do |inst|
        # contact or resolved
        cr_dup = criteria1.select do |inst1|
          inst1.course_user_datum_id == inst.course_user_datum_id and
            inst1.risk_condition_id == inst.risk_condition_id and
            inst1.violation_info == inst.violation_info
        end
        all_dup = false if cr_dup.count == 0
      end

      next if all_dup

      cur_instances.each do |inst|
        # new
        new_dup = criteria2.where(
          course_user_datum_id: inst.course_user_datum_id,
          risk_condition_id: inst.risk_condition_id,
          violation_info: inst.violation_info
        )
        if new_dup.count == 0
          new_instances << inst
        else
          deprecated_instances -= new_dup
        end
      end
    end

    ActiveRecord::Base.transaction do
      new_instances.each do |inst|
        next if inst.save

        raise "Fail to create new watchlist instance for CUD"\
              " #{inst.course_user_datum_id} in course"\
              " #{course.name} with violation info #{inst.violation_info}"
      end
    end

    [new_instances, deprecated_instances]
  end

  # The following 4 methods that create a watchlist instance for a course user datum does not
  # save a new instance itself. Whoever calls them are responsible for doing so!

  def self.add_new_instance_for_cud_grace_day_usage(course, condition_id,
                                                    cud, asmts_before_date, grace_day_threshold)
    auds_before_date = asmts_before_date.map { |asmt| asmt.aud_for(cud.id) }
    auds_before_date_filtered = auds_before_date.reject(&:nil?)
    if auds_before_date_filtered.count < auds_before_date.count
      raise "Assessment user datum does not exist for some"\
            " assessments for course user datum #{cud.id}"
    end

    latest_aud_before_date = auds_before_date.last

    return unless latest_aud_before_date.global_cumulative_grace_days_used >= grace_day_threshold

    violation_info = {}
    allowlist_asmt_cumulative_gdu = 0
    auds_before_date.each do |aud|
      if aud.grace_days_used > 0
        allowlist_asmt_cumulative_gdu += aud.grace_days_used
        violation_info[aud.assessment.display_name] = aud.grace_days_used
      end
    end

    # The logic might fall through if the grace days were used on blocklisted assessments
    # This ensures no funky "0 grace day used" instance is added
    return if allowlist_asmt_cumulative_gdu < grace_day_threshold

    WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                          risk_condition_id: condition_id,
                          violation_info:)
  end

  def self.add_new_instance_for_cud_extension_requests(course, category_blocklist,
                                                       condition_id, cud, extension_count)
    asmts = Assessment.where.not(category_name: category_blocklist)
    violation_info = {}
    num_of_extensions = 0

    asmts = course.exclude_curr_asmts(asmts)
    asmts = asmts.pluck(:id)

    asmts.each do |asmt|
      extensions = Extension.where(course_user_datum_id: cud.id, assessment_id: asmt)
      num_of_extensions += extensions.count
    end

    if num_of_extensions >= extension_count
      asmts.each do |asmt|
        extensions = Extension.where(course_user_datum_id: cud.id, assessment_id: asmt)
        aud = AssessmentUserDatum.find_by(course_user_datum_id: cud.id, assessment_id: asmt)
        indiv_extensions_count = extensions.count
        if indiv_extensions_count >= 1
          violation_info[aud.assessment.display_name] = indiv_extensions_count
        end
      end
    end

    return if violation_info.empty?

    WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                          risk_condition_id: condition_id,
                          violation_info:)
  end

  def self.add_new_instance_for_cud_grade_drop(course,
                                               condition_id, cud, asmt_arrs,
                                               consecutive_counts, percentage_drop)
    violation_info = {}
    asmt_arrs.each do |asmts|
      asmts = course.exclude_curr_asmts(asmts)
      auds = asmts.map do |asmt|
        AssessmentUserDatum.find_by(course_user_datum_id: cud.id, assessment_id: asmt.id)
      end
      auds_filtered = auds.reject(&:nil?)
      if auds_filtered.count < auds.count
        raise "Assessment user datum does not exist for some assessments "\
              "for course user datum #{cud.id}"
      end

      violating_pairs = []
      i = 0
      while i + consecutive_counts - 1 < auds.count
        begin_aud = auds[i]
        end_aud = auds[i + consecutive_counts - 1]
        begin_grade = begin_aud.final_score_ignore_grading_deadline(cud)
        end_grade = end_aud.final_score_ignore_grading_deadline(cud)
        if begin_grade.nil? || end_grade.nil?
          # - Either is excused
          i += 1
          next
        elsif (begin_aud.latest_submission && !begin_aud.latest_submission.all_scores_released?) ||
              (end_aud.latest_submission &&
                !end_aud.latest_submission.all_scores_released?)
          # - Score for either is not finalized and released to student yet
          i += 1
          next
        elsif begin_aud.latest_submission.nil? || end_aud.latest_submission.nil?
          # - Student didn't make any submission for either
          i += 1
          next
        end
        begin_total = begin_aud.assessment.default_total_score
        end_total = end_aud.assessment.default_total_score
        begin_grade_percent = begin_grade * 100.0 / begin_total
        end_grade_percent = end_grade * 100.0 / end_total
        if end_grade_percent >= begin_grade_percent
          i += 1
          next
        end
        diff = (begin_grade_percent - end_grade_percent) * 100.0 / begin_grade_percent
        if diff >= percentage_drop
          pair = {}
          pair[begin_aud.assessment.display_name] = "#{begin_grade}/#{begin_total}"
          pair[end_aud.assessment.display_name] = "#{end_grade}/#{end_total}"
          violating_pairs << pair
        end
        i += 1
      end
      violation_info[asmts[0].category_name] = violating_pairs if !violating_pairs.empty?
    end

    return if violation_info.empty?

    WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                          risk_condition_id: condition_id,
                          violation_info:)
  end

  def self.add_new_instance_for_cud_no_submissions(course,
                                                   category_blocklist,
                                                   condition_id,
                                                   cud,
                                                   no_submissions_threshold)
    asmts_ids = Assessment.where.not(category_name: category_blocklist)
    asmts_ids = course.exclude_curr_asmts(asmts_ids)
    asmts_ids = asmts_ids.pluck(:id)
    auds = AssessmentUserDatum.where(assessment_id: asmts_ids, course_user_datum_id: cud.id)
    no_submissions_asmt_names = []
    auds.each do |aud|
      if aud.submission_status == :not_submitted && aud.assessment
        no_submissions_asmt_names << aud.assessment.display_name
      end
    end
    return unless no_submissions_asmt_names.length >= no_submissions_threshold

    WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                          risk_condition_id: condition_id,
                          violation_info: {
                            no_submissions_asmt_names:
                          })
  end

  def self.add_new_instance_for_cud_low_grades(course,
                                               category_blocklist,
                                               condition_id,
                                               cud,
                                               grade_threshold,
                                               count_threshold)
    asmts_ids = Assessment.where.not(category_name: category_blocklist)
    asmts_ids = course.exclude_curr_asmts(asmts_ids)
    auds = AssessmentUserDatum.where(assessment_id: asmts_ids, course_user_datum_id: cud.id)
    violation_info = {}
    auds.each do |aud|
      aud_score = aud.final_score_ignore_grading_deadline(cud)
      # - Score is excused
      # - Score has not been released yet
      # - Student did not make any submissions at all
      if aud_score.nil? || aud.latest_submission.nil? || (aud.latest_submission &&
        !aud.latest_submission.all_scores_released?)
        next
      end

      total = aud.assessment.default_total_score
      score_percent = aud_score * 100.0 / total
      if score_percent < grade_threshold
        violation_info[aud.assessment.display_name] = "#{aud_score}/#{total}"
      end
    end
    return unless violation_info.length >= count_threshold

    WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                          risk_condition_id: condition_id,
                          violation_info:)
  end
end
