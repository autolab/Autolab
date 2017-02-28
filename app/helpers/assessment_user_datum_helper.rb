module AssessmentUserDatumHelper
  def grade_type_to_s(type)
    case type
    when AssessmentUserDatum::NORMAL
      "Normal"
    when AssessmentUserDatum::EXCUSED
      "Excused"
    when AssessmentUserDatum::ZEROED
      "Zeroed"
    end
  end

  # Due At in string form. If it is nil (meaning there is infinite extension), display appropriate information.
  def due_at_display(due_at)
    due_at.nil? ? "Not applicable (infinite extension granted)" : due_at.in_time_zone.to_s
  end

  # End At string form. If it is nil (meaning there is infinite extension), display appropriate information.
  def end_at_display(end_at)
    end_at.nil? ? "Not applicable (infinite extension granted)" : end_at.in_time_zone.to_s
  end
end
