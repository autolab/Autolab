class GradeMatrix
  attr_reader :course, :as_seen_by

  def initialize(course, as_seen_by)
    @course = course
    @as_seen_by = as_seen_by

    # TODO: make caching logic much more clear
    # only need to generate objects if they're going to be used
    cache_key = GradeMatrix.cache_key @course.id
    @matrix = Rails.cache.fetch cache_key do
      AssociationCache.new(@course) do |cache|
        cache.load_latest_submissions
        cache.load_auds
        cache.load_course_user_data
        cache.load_assessments
      end

      ActiveSupport::Gzip.compress(matrix!.to_json)
    end
    @matrix = JSON.parse ActiveSupport::Gzip.decompress(@matrix)
  end

  def last_updated
    @matrix["last_updated"]
  end

  def cell(asmt_id, cud_id)
    @matrix["cell_by_asmt"][asmt_id.to_s][cud_id.to_s]
  end

  def category_average(cat, cud_id)
    @matrix["cat_avg_by_cat"][cat.to_s][cud_id.to_s]
  end

  def course_average(cud_id)
    @matrix["course_avg_by_user"][cud_id.to_s]
  end

  def cells_for_assessment(asmt_id)
    @matrix["cell_by_asmt"][asmt_id.to_s].values
  end

  def averages_for_category(cat)
    @matrix["cat_avg_by_cat"][cat.to_s].values
  end

  def course_averages
    @matrix["course_avg_by_user"].values
  end

  # Check whether the specified assessment is included in the GradeMatrix cache
  # This is necessary when clients are using a cached GradeMatrix that might not
  # be up to date with the current course (e.g.: an assessment was added since)
  def has_assessment?(asmt_id)
    @matrix["cell_by_asmt"][asmt_id.to_s] != nil
  end

  # Check whether the specified user is included in the GradeMatrix cache
  def has_cud?(cud_id)
    @matrix["course_avg_by_user"][cud_id.to_s] != nil
  end

  # Check whether the specified category is included in the GradeMatrix cache
  def has_category?(cat)
    @matrix["cat_avg_by_cat"][cat.to_s] != nil
  end

  def self.invalidate(course)
    Rails.cache.delete cache_key(course.id)
  end

  def self.cache_key(course_id)
    "course_#{course_id}_grade_matrix"
  end

private

  def matrix!
    cell_by_asmt = {}
    cat_avg_by_cat = {}
    course_avg_by_user = {}

    @course.course_user_data.each do |cud|
      next unless cud.student?
      next if cud.dropped?

      @course.assessments.each do |a|
        s = summarize a.aud_for(cud.id)
        cell_by_asmt[a.id.to_s] ||= {}
        cell_by_asmt[a.id.to_s][cud.id.to_s] = s
      end

      @course.assessment_categories.each do |cat|
        a = cud.category_average(cat, @as_seen_by)
        cat_avg_by_cat[cat] ||= {}
        cat_avg_by_cat[cat][cud.id.to_s] = a
      end

      course_avg_by_user[cud.id.to_s] = cud.average @as_seen_by
    end

    {
      "cell_by_asmt" => cell_by_asmt,
      "cat_avg_by_cat" => cat_avg_by_cat,
      "course_avg_by_user" => course_avg_by_user,
      "last_updated" => Time.current
    }
  end

  def summarize(aud)
    info = {}

    info["status"] = aud.status @as_seen_by
    info["version"] = aud.latest_submission&.version
    info["final_score"] = aud.final_score @as_seen_by
    info["grade_type"] = (AssessmentUserDatum.grade_type_to_sym aud.grade_type).to_s
    info["submission_status"] = aud.submission_status.to_s
    info["grace_days"] = aud.grace_days_used
    info["late_days"] = aud.penalty_late_days

    # TODO: need to convert this to local time on *client*
    # TODO: convert to 12-hour time
    if aud.end_at.nil? # Infinite extension.
      info["end_at"] = end_at_display(aud.end_at)
    else # Finite (or zero) extension.
      # Convert the format from "to_s" to "to_formatted_s :long".
      end_at = end_at_display(aud.end_at).to_datetime
      info["end_at"] = end_at.to_formatted_s :long
    end

    info
  end

  include AssessmentUserDatumHelper
end
