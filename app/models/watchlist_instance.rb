class WatchlistInstance < ApplicationRecord
  enum status: [:new ,:contacted,:resolved], _suffix:"watchlist"
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
  
  def self.get_num_new_instance_for_course(course_name)
    begin
      course_id = Course.find_by(name:course_name).id
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end 
    return WatchlistInstance.where(course_id:course_id,status: :new).count()
  end 

  def self.refresh_instances_for_course(course_name)
    begin
      course = Course.find_by(name: course_name)
      current_conditions = RiskCondition.get_current_for_course(course_name)
      current_instances = WatchlistInstance.where(course_id: course.id)
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end

    # check whether the watchlist instances are up-to-date
    current_instances_condition_ids = (current_instances.map { |inst| inst.risk_condition_id }).uniq.to_set
    current_condition_ids = (current_conditions.map { |c| c.id }).uniq.to_set # should be unique by design but add the suffix to ensure
    if current_instances_condition_ids == current_condition_ids
      return current_instances
    else
      # update!
      # archive previous watchlist instances first
      for instance in current_instances
        instance.archive_watchlist_instance
      end
      # now check current conditions
      if current_conditions.length == 0
        # case 1: no current risk conditions exist
        return []
      else
        # case 2: current risk conditions exist
        new_instances = self.add_new_instances_for_conditions(current_conditions, course)
        return new_instances
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

  def archive_watchlist_instance
    if self.new_watchlist?
      self.destroy
    else
      self.archived = true
      if not self.save
        raise "Failed to archive watchlist instance for user #{self.course_user_datum.user_id} in course #{self.course.display_name}"
      end
    end
  end

  def contact_watchlist_instance
    if self.new_watchlist?
      self.contacted_watchlist!
      
      if not self.save
        raise "Failed to update watchlist instance #{self.id} to contacted" unless self.save
      end
    else
      raise "Unable to contact a watchlist instance that is not new #{self.id}"
    end
  end

  def resolve_watchlist_instance
    if (self.new_watchlist? || self.contacted_watchlist?)
      self.resolved_watchlist!

      if not self.save
        raise "Failed to update watchlist instance #{self.id} to resolved" unless self.save
      end
    else
      raise "Unable to resolve a watchlist instance that is not new or contacted #{self.id}"
    end
  end

private
  
  def self.add_new_instances_for_conditions(conditions, course)
    new_instances = []
    course_user_data = CourseUserDatum.where(course_id: course.id, instructor: false, course_assistant: false)
    # HUGE TRANSACTION AHEAD
    ActiveRecord::Base.transaction do
      conditions.each do |condition|
        case condition.condition_type
        
        when "grace_day_usage"
          grace_day_threshold = condition.parameters[:grace_day_threshold]
          date = condition.parameters[:date]
          asmts = course.assessments.ordered
          for cud in course_user_data
            asmts_before_date = asmts.where("updated_at < ?", date)
            latest_asmt = asmts_before_date.last
            next if latest_asmt.nil?
            new_instance = self.add_new_instance_for_cud_grace_day_usage(course, condition.id, cud, asmts_before_date, grace_day_threshold)
            new_instances << new_instance unless new_instance.nil?
          end

        when "grade_drop"
          percentage_drop = (condition.parameters[:percentage_drop]).to_f
          consecutive_counts = condition.parameters[:consecutive_counts]
          
          categories = course.assessment_categories
          asmt_arrs = categories.map { |category| course.assessments_with_category(category).ordered }
          asmt_arrs.select! { |asmts| asmts.count >= consecutive_counts}
          for cud in course_user_data
            new_instance = self.add_new_instance_for_cud_grade_drop(course, condition.id, cud, asmt_arrs, consecutive_counts, percentage_drop)
            new_instances << new_instance unless new_instance.nil?
          end

        when "no_submissions"
          no_submissions_threshold = condition.parameters[:no_submissions_threshold]

          for cud in course_user_data
            new_instance = self.add_new_instance_for_cud_no_submissions(course, condition.id, cud, no_submissions_threshold)
            new_instances << new_instance unless new_instance.nil?
          end

        when "low_grades"
          grade_threshold = condition.parameters[:grade_threshold].to_f
          count_threshold = condition.parameters[:count_threshold]

          for cud in course_user_data
            new_instance = self.add_new_instance_for_cud_low_grades(course, condition.id, cud, grade_threshold, count_threshold)
            new_instances << new_instance unless new_instance.nil?
          end
        end
      end
    end

    return new_instances
  end

  def self.add_new_instance_for_cud_grace_day_usage(course, condition_id, cud, asmts_before_date, grace_day_threshold)
    auds_before_date = asmts_before_date.map { |asmt| AssessmentUserDatum.find_by(course_user_datum_id: cud.id, assessment_id: asmt.id) }
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
      if not new_instance.save
        raise "Fail to create new watchlist instance for CUD #{cud.id} in course #{course.name} with violation info #{violation_info}"
      end
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
        begin_grade = begin_aud.final_score(cud)
        end_grade = end_aud.final_score(cud)
        # - Grading deadline has not passed yet
        # - Score is not finalized and released to student yet
        if end_grade.nil? or begin_grade.nil?
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
      if not new_instance.save
        raise "Fail to create new watchlist instance for CUD #{cud.id} in course #{course.name} with violation info #{violation_info}"
      end
      return new_instance
    end
  end

  def self.add_new_instance_for_cud_no_submissions(course, condition_id, cud, no_submissions_threshold)
    auds = AssessmentUserDatum.where(course_user_datum_id: cud.id)
    no_submissions_asmt_names = []
    auds.each do |aud|
      no_submissions_asmt_names << aud.assessment.display_name if aud.latest_submission.nil?
    end
    if no_submissions_asmt_names.length >= no_submissions_threshold
      new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: course.id,
                                           risk_condition_id: condition_id,
                                           violation_info: { :no_submissions_asmt_names => no_submissions_asmt_names })
      if not new_instance.save
        raise "Fail to create new watchlist instance for CUD #{cud.id} in course #{course.name} with violation info #{violation_info}"
      end
      return new_instance
    end
  end

  def self.add_new_instance_for_cud_low_grades(course, condition_id, cud, grade_threshold, count_threshold)
    auds = AssessmentUserDatum.where(course_user_datum_id: cud.id)
    violation_info = {}
    auds.each do |aud|
      aud_score = aud.final_score(cud)
      # score not out yet
      next if aud_score.nil?
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
      if not new_instance.save
        raise "Fail to create new watchlist instance for CUD #{cud.id} in course #{course.name} with violation info #{violation_info}"
      end
      return new_instance
    end
  end

end
