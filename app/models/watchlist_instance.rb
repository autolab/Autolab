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

end
