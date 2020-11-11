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

  def self.refresh_instances_for_course(course_name)
    begin
      course_id = Coures.find_by(name: coures_name).id
      current_conditions = RiskCondition.get_current_for_course(coures_name)
      current_instances = WatchlistInstance.where(course_id: course_id)
    rescue NoMethodError
      raise "Course #{course_name} cannot be found"
    end

    # check whether the watchlist instances are up-to-date
    current_instances_condition_ids = (current_instances.map { |inst| inst.risk_condition_id }).uniq.to_set
    current_condition_ids = (current_conditions.map { |c| c.id }).uniq.to_set # should be unique by design but add the suffix to ensure
    if current_instances_conditions_ids == current_instances_conditions_ids
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
        new_instances = self.add_new_instances_for_conditions(current_conditions, course_id)
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
  
  def self.add_new_instances_for_conditions(conditions)
    # grace_day_usage: grace_day_threshold x and date y
    # grade_drop => percentage_drop x, consecutive_counts y
    # no_submissions => no_submissions_threshold x
    # low_grades => grade_threshold x, count_threshold y
    new_instances = []
    for condition in conditions
      case condition.condition_type
      when "grace_day_usage"
        grace_day_threshold = condition.parameters[:grace_day_threshold]
        date = condition.parameters[:date]
        # assume for now date takes on the form "yyyy-mm-dd"
        course_user_data = CourseUserDatum.where(course_id: course_id, instructor: false, course_assistant: false)
        for cud in course_user_data
          latest_aud_before_date = AssessmentUserDatum.where(course_user_datum_id: cud.id).
                                                       where("updated_at < ?", date).
                                                       order("updated_at DESC").first
          next if latest_aud_before_date.nil?
          if latest_aud_before_date.global_cumulative_grace_days_used >= grace_day_threshold
            # add new instance
            new_instance = WatchlistInstance.new(course_user_datum_id: cud.id, course_id: condition.course_id,
                                                 risk_condition_id: condition.id,
                                                 violation_info: {}, # TODO
                                                 )
            new_instances << new_instance;
          end
        end
      when "grade_drop"
        percentage_drop = condition.parameters[:percentage_drop]
        consecutive_counts = condition.parameters[:consecutive_counts]
      when "no_submissions"
        no_submissions_threshold = condition.parameters[:no_submissions_threshold]
      when "low_grades"
        grade_threshold = condition.parameters[:grade_threshold]
        count_threshold = condition.parameters[:count_threshold]
      end
    end
  end

end
