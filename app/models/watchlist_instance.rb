class WatchlistInstance < ApplicationRecord
  enum status: [:pending, :contacted, :resolved], _suffix:"watchlist"
  belongs_to :course_user_datum
  belongs_to :course
  belongs_to :risk_condition

  def self.get_instances_for_course(course_name)
    begin
      course_id = Course.find_by(name:course_name).id
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end 
    return WatchlistInstance.where(course_id:course_id)
  end
  
  def self.get_num_pending_instance_for_course(course_name)
    begin
      course_id = Course.find_by(name:course_name).id
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end 
    return WatchlistInstance.where(course_id:course_id, status: :pending).distinct.count(:course_user_datum_id)
  end 

  def self.refresh_instances_for_course(course_name, metrics_update=false)
    begin
      course = Course.find_by(name: course_name)
      current_conditions = RiskCondition.get_current_for_course(course_name)
      current_instances = WatchlistInstance.where(course_id: course.id, archived: false)
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end

    # update!
    new_instances = []
    deprecated_instances = current_instances
    # now check current conditions
    if current_conditions.length == 0
      # case 1: no current risk conditions exist
      # no-op
    else
      # case 2: current risk conditions exist
      new_instances, deprecated_instances = self.add_new_instances_for_conditions(current_conditions, course, current_instances)
    end

    # archive previous watchlist instances
    if metrics_update
      for instance in deprecated_instances
        instance.archive_watchlist_instance
      end
    end

    return new_instances
  end
  
  # Update the grace day usage condition watchlist instances for each course user datum of a particular course
  # This is called when:
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
        old_instances.each do |inst|
          inst.archive_watchlist_instance
        end
      end
      return
    end
    course_user_data.each do |cud|
      new_instance = self.add_new_instance_for_cud_grace_day_usage(course, condition_id, cud, asmts_before_date, grace_day_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each do |inst|
        inst.archive_watchlist_instance
      end

      new_instances.each do |inst|
        if not inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id} in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  def self.update_cud_gdu_watchlist_instances(cud)

    # Ignore if this CUD is an instructor or CA or dropped
    return unless (cud.student? and (cud.dropped == false or cud.dropped.nil?))
    
    # Get current grace day condition
    parameters = RiskCondition.get_gdu_condition_for_course(cud.course.name)
    return if parameters.nil?

    condition_id, grace_day_threshold, date = parameters
    
    # Archive old ones if there exist some
    old_instances = cud.watchlist_instances.where(risk_condition_id: condition_id)

    asmts_before_date = cud.course.asmts_before_date(date)
    if asmts_before_date.count == 0
      ActiveRecord::Base.transaction do
        old_instances.each do |inst|
          inst.archive_watchlist_instance
        end
      end
      return
    end
    
    # Do the usual stuff as in refresh watchlist instances
    # Create a new instance if criteria are fit
    new_instance = self.add_new_instance_for_cud_grace_day_usage(cud.course, condition_id, cud, asmts_before_date, grace_day_threshold)

    ActiveRecord::Base.transaction do
      old_instances.each do |inst|
        inst.archive_watchlist_instance
      end

      unless new_instance.nil?
        if not new_instance.save
          raise "Fail to create new watchlist instance for CUD #{cud.id} in course #{cud.course.name} with violation info #{new_instance.violation_info}"
        end
      end
    end
  end

  def self.update_course_grade_watchlist_instances(course)
    parameters_grade_drop = RiskCondition.get_grade_drop_condition_for_course(course.name)
    parameters_low_grades = RiskCondition.get_low_grades_condition_for_course(course.name)
    return if parameters_grade_drop.nil? and parameters_low_grades.nil?

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
        new_instance = self.add_new_instance_for_cud_grade_drop(course, grade_drop_condition_id, cud, asmt_arrs, consecutive_counts, percentage_drop)
        new_instances << new_instance unless new_instance.nil?
      end
    end

    unless parameters_low_grades.nil?
      low_grades_condition_id, grade_threshold, count_threshold = parameters_low_grades
      old_instances += course.watchlist_instances.where(risk_condition_id: low_grades_condition_id)

      course_user_data.each do |cud|
        new_instance = self.add_new_instance_for_cud_low_grades(course, low_grades_condition_id, cud, grade_threshold, count_threshold)
        new_instances << new_instance unless new_instance.nil?
      end
    end

    ActiveRecord::Base.transaction do
      old_instances.each do |inst|
        inst.archive_watchlist_instance
      end

      new_instances.each do |inst|
        if not inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id} in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  def self.update_individual_grade_watchlist_instances(cud)
    # Ignore if this CUD is an instructor or CA or dropped
    return unless (cud.student? and (cud.dropped == false or cud.dropped.nil?))

    # Get current grade condition
    parameters_grade_drop = RiskCondition.get_grade_drop_condition_for_course(cud.course.name)
    parameters_low_grades = RiskCondition.get_low_grades_condition_for_course(cud.course.name)
    return if parameters_grade_drop.nil? and parameters_low_grades.nil?

    old_instances = []
    new_instances = []

    unless parameters_grade_drop.nil?
      grade_drop_condition_id, percentage_drop, consecutive_counts = parameters_grade_drop
      old_instances += cud.watchlist_instances.where(risk_condition_id: grade_drop_condition_id)
      categories = cud.course.assessment_categories
      asmt_arrs = categories.map { |category| cud.course.assessments_with_category(category).ordered }
      asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts }

      new_instance = self.add_new_instance_for_cud_grade_drop(cud.course, grade_drop_condition_id, cud, asmt_arrs, consecutive_counts, percentage_drop)
      new_instances << new_instance unless new_instance.nil?
    end

    unless parameters_low_grades.nil?
      low_grades_condition_id, grade_threshold, count_threshold = parameters_low_grades
      old_instances += cud.watchlist_instances.where(risk_condition_id: low_grades_condition_id)

      new_instance = self.add_new_instance_for_cud_low_grades(cud.course, low_grades_condition_id, cud, grade_threshold, count_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each do |inst|
        inst.archive_watchlist_instance
      end

      new_instances.each do |inst|
        if not inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id} in course #{cud.course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

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
      new_instance = add_new_instance_for_cud_no_submissions(course, condition_id, cud, no_submissions_threshold)
      new_instances << new_instance unless new_instance.nil?
    end

    ActiveRecord::Base.transaction do
      old_instances.each do |inst|
        inst.archive_watchlist_instance
      end

      new_instances.each do |inst|
        if not inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id} in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end
  end

  def self.contact_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id:instance_ids)
    if instance_ids.length() != instances.length()
      found_instance_ids = instances.map{|instance| instance.id}
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end
    ActiveRecord::Base.transaction do
      instances.each do |instance|
        instance.contact_watchlist_instance
      end
    end
  end
  
  def self.resolve_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id:instance_ids)
    if instance_ids.length() != instances.length()
      found_instance_ids = instances.map{|instance| instance.id}
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end
    
    ActiveRecord::Base.transaction do
      instances.each do |instance|
        instance.resolve_watchlist_instance
      end
    end
  end

  def self.delete_many_watchlist_instances(instance_ids)
    instances = WatchlistInstance.where(id:instance_ids)
    if instance_ids.length() != instances.length()
      found_instance_ids = instances.map{|instance| instance.id}
      raise "Instance ids #{instance_ids - found_instance_ids} cannot be found"
    end
    
    ActiveRecord::Base.transaction do
      instances.each do |instance|
        instance.delete_watchlist_instance
      end
    end
  end

  def archive_watchlist_instance
    if self.pending_watchlist?
      self.destroy
    else
      self.archived = true
      if not self.save
        raise "Failed to archive watchlist instance for user #{self.course_user_datum.user_id} in course #{self.course.display_name}"
      end
    end
  end

  def contact_watchlist_instance
    if self.pending_watchlist?
      self.contacted_watchlist!
      
      if not self.save
        raise "Failed to update watchlist instance #{self.id} to contacted" unless self.save
      end
    else
      raise "Unable to contact a watchlist instance that is not pending #{self.id}"
    end
  end

  def resolve_watchlist_instance
    if (self.pending_watchlist? || self.contacted_watchlist?)
      self.resolved_watchlist!

      if not self.save
        raise "Failed to update watchlist instance #{self.id} to resolved" unless self.save
      end
    else
      raise "Unable to resolve a watchlist instance that is not pending or contacted #{self.id}"
    end
  end

   def delete_watchlist_instance
    if (self.archived?)
      self.destroy
    else
      raise "Unable to delete a watchlist instance that is not pending or archived #{self.id}"
    end
  end

private
  
  def self.add_new_instances_for_conditions(conditions, course, current_instances)
    new_instances = []
    course_user_data = CourseUserDatum.where(course_id: course.id, instructor: false, course_assistant: false)

    # new
    criteria2 = current_instances.where(status: :pending)
    # contacted or resolved
    criteria1 = current_instances - criteria2
    deprecated_instances = current_instances
    
    for cud in course_user_data
      cur_instances = []
      conditions.each do |condition|
        case condition.condition_type
        
        when "grace_day_usage"
          grace_day_threshold = condition.parameters[:grace_day_threshold].to_i
          date = condition.parameters[:date]
          asmts_before_date = course.asmts_before_date(date)
          next if asmts_before_date.count == 0 # go to the next condition loop if there is no latest assessment
          new_instance = self.add_new_instance_for_cud_grace_day_usage(course, condition.id, cud, asmts_before_date, grace_day_threshold)
          cur_instances << new_instance unless new_instance.nil?
        
        when "grade_drop"
          percentage_drop = (condition.parameters[:percentage_drop]).to_f
          consecutive_counts = condition.parameters[:consecutive_counts].to_i
          
          categories = course.assessment_categories
          asmt_arrs = categories.map { |category| course.assessments_with_category(category).ordered }
          asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts}
          new_instance = self.add_new_instance_for_cud_grade_drop(course, condition.id, cud, asmt_arrs, consecutive_counts, percentage_drop)
          cur_instances << new_instance unless new_instance.nil?

        when "no_submissions"
          no_submissions_threshold = condition.parameters[:no_submissions_threshold].to_i

          new_instance = self.add_new_instance_for_cud_no_submissions(course, condition.id, cud, no_submissions_threshold)
          cur_instances << new_instance unless new_instance.nil?

        when "low_grades"
          grade_threshold = condition.parameters[:grade_threshold].to_f
          count_threshold = condition.parameters[:count_threshold].to_i

          new_instance = self.add_new_instance_for_cud_low_grades(course, condition.id, cud, grade_threshold, count_threshold)
          cur_instances << new_instance unless new_instance.nil?
        end
      end
      # check for duplication
      all_dup = true
      cur_instances.each do |inst|
        # contact or resolved
        cr_dup = criteria1.select { |inst1|
          inst1.course_user_datum_id == inst.course_user_datum_id and
          inst1.risk_condition_id == inst.risk_condition_id and
          inst1.violation_info == inst.violation_info
        }
        if cr_dup.count == 0
          all_dup = false
        end
      end

      if not all_dup
        cur_instances.each do |inst|
          # new
          new_dup = criteria2.where(
            course_user_datum_id: inst.course_user_datum_id,
            risk_condition_id: inst.risk_condition_id,
            violation_info: inst.violation_info
          )
          if new_dup.count == 0
            new_instances << inst;
          else
            deprecated_instances = deprecated_instances - new_dup
          end
        end
      end
    end

    ActiveRecord::Base.transaction do
      new_instances.each do |inst|
        if not inst.save
          raise "Fail to create new watchlist instance for CUD #{inst.course_user_datum_id} in course #{course.name} with violation info #{inst.violation_info}"
        end
      end
    end

    return new_instances, deprecated_instances
  end

  # The following 4 methods that create a watchlist instance for a course user datum does not
  # save a new instance itself. Whoever calls them are responsible for doing so!

  def self.add_new_instance_for_cud_grace_day_usage(course, condition_id, cud, asmts_before_date, grace_day_threshold)
    auds_before_date = asmts_before_date.map { |asmt| asmt.aud_for(cud.id) }
    auds_before_date_filtered = auds_before_date.select { |aud| not aud.nil? }
    if auds_before_date_filtered.count < auds_before_date.count
      raise "Assessment user datum does not exist for some assessments for course user datum #{cud.id}"
    end
    latest_aud_before_date = auds_before_date.last
    if latest_aud_before_date.global_cumulative_grace_days_used >= grace_day_threshold
      violation_info = {}
      auds_before_date.each do |aud|
        violation_info[aud.assessment.display_name] = aud.grace_days_used if aud.grace_days_used > 0
      end
      new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                                           risk_condition_id: condition_id,
                                           violation_info: violation_info)
      return new_instance
    end
  end

  def self.add_new_instance_for_cud_grade_drop(course, condition_id, cud, asmt_arrs, consecutive_counts, percentage_drop)
    violation_info = {}
    for asmts in asmt_arrs
      auds = asmts.map { |asmt| AssessmentUserDatum.find_by(course_user_datum_id: cud.id, assessment_id: asmt.id) }
      auds_filtered = auds.select { |aud| not aud.nil? }
      if auds_filtered.count < auds.count
        raise "Assessment user datum does not exist for some assessments for course user datum #{cud.id}"
      end
      violating_pairs = []
      i = 0
      while i+consecutive_counts-1 < auds.count
        begin_aud = auds[i]
        end_aud = auds[i+consecutive_counts-1]
        begin_grade = begin_aud.final_score_ignore_grading_deadline(cud)
        end_grade = end_aud.final_score_ignore_grading_deadline(cud)
        if begin_grade.nil? or end_grade.nil?
          # - Either is excused
          i = i + 1
          next
        elsif (begin_aud.latest_submission and not begin_aud.latest_submission.all_scores_released?) or
              (end_aud.latest_submission and not end_aud.latest_submission.all_scores_released?)
          # - Score for either is not finalized and released to student yet
          i = i + 1
          next
        elsif begin_aud.latest_submission.nil? or end_aud.latest_submission.nil?
          # - Student didn't make any submission for either
          i = i + 1
          next
        end
        begin_total = begin_aud.assessment.default_total_score
        end_total = end_aud.assessment.default_total_score
        begin_grade_percent = begin_grade * 100.0 / begin_total
        end_grade_percent = end_grade * 100.0 / end_total
        if end_grade_percent >= begin_grade_percent
          i = i + 1
          next
        end
        diff = (begin_grade_percent - end_grade_percent) * 100.0 / begin_grade_percent
        if diff >= percentage_drop
          pair = {}
          pair[begin_aud.assessment.display_name] = "#{begin_grade}/#{begin_total}"
          pair[end_aud.assessment.display_name] = "#{end_grade}/#{end_total}"
          violating_pairs << pair
        end
        i = i + 1
      end
      violation_info[asmts[0].category_name] = violating_pairs if violating_pairs.length > 0
    end

    if violation_info.length > 0
      new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                                           risk_condition_id: condition_id,
                                           violation_info: violation_info)
      return new_instance
    end
  end

  def self.add_new_instance_for_cud_no_submissions(course, condition_id, cud, no_submissions_threshold)
    auds = AssessmentUserDatum.where(course_user_datum_id: cud.id)
    no_submissions_asmt_names = []
    auds.each do |aud|
      no_submissions_asmt_names << aud.assessment.display_name if aud.submission_status == :not_submitted
    end
    if no_submissions_asmt_names.length >= no_submissions_threshold
      new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                                           risk_condition_id: condition_id,
                                           violation_info: { :no_submissions_asmt_names => no_submissions_asmt_names })
      return new_instance
    end
  end

  def self.add_new_instance_for_cud_low_grades(course, condition_id, cud, grade_threshold, count_threshold)
    auds = AssessmentUserDatum.where(course_user_datum_id: cud.id)
    violation_info = {}
    auds.each do |aud|
      aud_score = aud.final_score_ignore_grading_deadline(cud)
      # - Score is excused
      # - Score has not been released yet
      # - Student did not make any submissions at all
      if aud_score.nil? or
         aud.latest_submission.nil? or
         (aud.latest_submission and not aud.latest_submission.all_scores_released?)
        next
      end
      total = aud.assessment.default_total_score
      score_percent = aud_score * 100.0 / total
      if score_percent < grade_threshold
        violation_info[aud.assessment.display_name] = "#{aud_score}/#{total}"
      end
    end
    if violation_info.length >= count_threshold
      new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                                           risk_condition_id: condition_id,
                                           violation_info: violation_info)
      return new_instance
    end
  end

end
