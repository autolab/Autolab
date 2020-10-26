class WatchlistInstance < ApplicationRecord
  belongs_to :course_user_datum
  belongs_to :course
  belongs_to :risk_condition

  NEW = 0
  CONTACTED = 1
  RESOLVED = 2

  def archive_watchlist_instance
    if self.status == NEW
      self.destroy
    else
      self.archived = true
      if not self.save
        raise "Failed to archive watchlist instance for user #{self.course_user_datum.user_id} in course #{self.course.display_name}"
      end
    end
  end

  def contact_watchlist_instance
    if self.status == NEW
      self.status == CONTACTED
      
      if not self.save
        raise "Failed to update watchlist instance #{self.id} to contacted" unless self.save
      end
    else
      raise "Unable to contact a watchlist instance that is not new #{self.id}"
    end
  end

  def resolve_watchlist_instance
    if self.status == NEW
      self.status == RESOLVED

      if not self.save
        raise "Failed to update watchlist instance #{self.id} to resolved" unless self.save
      end
    else
      raise "Unable to resolve a watchlist instance that is not new #{self.id}"
    end
  end

end
