require "utilities"

module GradebookHelper
  def gradebook_columns(matrix, course)
    # user info columns
    columns = [
      { id: "number", name: "#", field: "", width: 50 },
      { id: "email", name: "Email", field: "email",
        sortable: true, width: 100, cssClass: "email",
        headerCssClass: "email" },
      { id: "first_name", name: "First", field: "first_name",
        sortable: true, width: 100, cssClass: "first_name",
        headerCssClass: "first_name" },
      { id: "last_name", name: "Last", field: "last_name",
        sortable: true, width: 100, cssClass: "last_name",
        headerCssClass: "last_name" },
      { id: "section", name: "Sec", field: "section",
        sortable: true, width: 50 },
      { id: "grace_days", name: "Grace Days Used", field: "grace_days",
        sortable: true, width: 50},
      { id: "late_days", name: "Penalty Late Days", field: "late_days",
        sortable: true, width: 50}
    ]

    course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat

      # assessment column
      course.assessments_with_category(cat).each do |asmt|
        next unless matrix.has_assessment? asmt.id

        columns << { id: asmt.name, name: asmt.display_name, field: asmt.name,
                     sortable: true, cssClass: "computed assessment_final_score",
                     headerCssClass: "assessment_final_score",
                     before_grading_deadline: matrix.before_grading_deadline?(asmt.id) }
      end

      # category aggregate column -- ignore those with a name that's nil
      if not matrix.category_aggregate_name(cat).nil?
        columns << { id: cat, name: cat + " #{matrix.category_aggregate_name(cat)}",
                     field: "#{cat}_category_aggregate",
                     sortable: true, cssClass: "computed category_average",
                     headerCssClass: "category_average", width: 100 }
      end
    end

    # course aggregate column
    columns << { id: "aggregate", name: "#{matrix.course_aggregate_name}", field: "course_aggregate",
                 sortable: true, width: 100, cssClass: "computed course_average",
                 headerCssClass: "course_average" }

    columns << { id: "email_right", name: "Email", field: "email",
                 sortable: true, width: 100, cssClass: "email right",
                 headerCssClass: "email right" }

    columns
  end

  def gradebook_rows(matrix, course, section = nil, lecture = nil)
    rows = []

    course.course_user_data.each do |cud|
      next unless matrix.has_cud? cud.id

      # if this is a section gradebook
      next unless cud.section == section if section

      next unless cud.lecture == lecture if lecture

      sgb_link = url_for controller: :gradebooks, action: :student, id: cud.id

      row = {}
      grace_days = 0
      late_days = 0

      row["id"] = cud.id
      row["email"] = cud.user.email
      row["student_gradebook_link"] = sgb_link
      row["first_name"] = cud.user.first_name
      row["last_name"] = cud.user.last_name
      row["section"] = cud.section

      # TODO: formalize score render stack, consolidate with computed score
      course.assessments.ordered.each do |a|
        next unless matrix.has_assessment? a.id

        cell = matrix.cell(a.id, cud.id)
        row[a.name] = round cell["final_score"]
        row["#{a.name}_submission_status"] = cell["submission_status"]
        row["#{a.name}_grade_type"] = cell["grade_type"]
        row["#{a.name}_end_at"] = cell["end_at"]

        # Specify default option of 0, because it is possible to end up getting
        # a cell that contains nil sometimes. Currently all other row entries above
        # are able to accept nil values.
        grace_days += cell["grace_days"] || 0
        late_days += cell["late_days"] || 0
      end

      course.assessment_categories.each do |cat|
        next unless matrix.has_category? cat

        key = "#{cat}_category_aggregate"
        row[key] = round matrix.category_aggregate(cat, cud.id)
      end

      row["course_aggregate"] = round matrix.course_aggregate(cud.id)
      row["grace_days"] = grace_days
      row["late_days"] = late_days

      rows << row
    end

    rows
  end

  def regenerate_url
    url_for controller: :gradebooks, action: :invalidate
  end

  def csv_header(matrix, course)
    header = %w(Email first_name last_name Lecture Section School Major Year grace_days_used penalty_late_days)
    course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat
      course.assessments_with_category(cat).each do |asmt|
        next unless matrix.has_assessment? asmt.id
        header << asmt.name
      end
      header << "#{cat} #{matrix.category_aggregate_name(cat)}"
    end
    header << "Course #{matrix.course_aggregate_name}"

    header
  end

  def formatted_status(status)
    case status
      when Float
        round status
      when String
        status
      else
        throw "FATAL: AUD status must be Float or String; was #{status.class}"
    end
  end

  def gradebook_csv(matrix, course)
    CSV.generate do |csv|
      csv << csv_header(matrix, course)

      course.course_user_data.each do |cud|
        next unless matrix.has_cud? cud.id

        grace_days = 0
        late_days = 0

        # general info
        row = [cud.user.email, cud.user.first_name, cud.user.last_name, cud.lecture, cud.section, cud.school, cud.major, cud.year, grace_days, late_days]

        # assessment status (see AssessmentUserDatum.status), category aggregates
        course.assessment_categories.each do |cat|
          next unless matrix.has_category? cat
          course.assessments_with_category(cat).each do |asmt|
            next unless matrix.has_assessment? asmt.id
            cell = matrix.cell(asmt.id, cud.id)

            row << formatted_status(cell["status"])
            grace_days += cell["grace_days"]
            late_days += cell["late_days"]
          end

          row << round(matrix.category_aggregate(cat, cud.id))
        end

        # course aggregate
        row << round(matrix.course_aggregate(cud.id))

        # update grace_days and late_days data
        row[8] = grace_days
        row[9] = late_days

        # add to csv
        csv << row
      end
    end
  end
end
