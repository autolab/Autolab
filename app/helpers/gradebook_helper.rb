require 'utilities'

module GradebookHelper
  def gradebook_columns(matrix, course)
    # user info columns
    columns = [
      { :id => "number", :name => "#", :field => "", width: 50 },
      { :id => "email", :name => "Email", :field => "email",
        :sortable => true, :width => 100, :cssClass => "email",
        :headerCssClass => "email" },
      { :id => "first_name", :name => "First", :field => "first_name",
        :sortable => true, :width => 100, :cssClass => "first_name",
        :headerCssClass => "first_name" },
      { :id => "last_name", :name => "Last", :field => "last_name",
        :sortable => true, :width => 100, :cssClass => "last_name",
        :headerCssClass => "last_name" },
      { :id => "section", :name => "Sec", :field => "section",
        :sortable => true, :width => 50 }
    ]

    course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat.id

      # assessment column
      cat.assessments.ordered.each do |a|
        next unless matrix.has_assessment? a.id

        columns << { :id => a.name, :name => a.display_name, :field => a.name,
                     :sortable => true, :cssClass => "computed assessment_final_score",
                     :headerCssClass => "assessment_final_score",
                     :before_grading_deadline => matrix.before_grading_deadline?(a.id) }
      end

      # category average column
      columns << { :id => cat.name, :name => cat.name + ' Average',
                   :field => "#{cat.name}_category_average",
                   :sortable => true, :cssClass => "computed category_average",
                   :headerCssClass => "category_average", width: 100 }
    end

    # course average column
    columns << { :id => "average", :name => "Average", :field => "course_average",
                 :sortable => true, width: 100, :cssClass => "computed course_average",
                 :headerCssClass => "course_average" }

    columns << { :id => "email_right", :name => "Email", :field => "email",
                 :sortable => true, :width => 100, :cssClass => "email right",
                 :headerCssClass => "email right" }

    columns
  end

  def gradebook_rows(matrix, course, section = nil, lecture = nil)
    rows = []

    course.course_user_data.each do |cud|
      next unless matrix.has_cud? cud.id

      # if this is a section gradebook
      if section
        next unless cud.section == section
      end

      if lecture
        next unless cud.lecture == lecture
      end

      sgb_link = url_for controller: :gradebooks, action: :student, id: cud.id

      row = {}

      row["id"] = cud.id
      row["email"] = cud.user.email
      row["student_gradebook_link"] = sgb_link
      row["first_name"] = cud.user.first_name
      row["last_name"] = cud.user.last_name
      row["section"] = cud.section

      # TODO: formalize score render stack, consolidate with computed score
      course.assessments.each do |a|
        next unless matrix.has_assessment? a.id

        cell = matrix.cell(a.id, cud.id)
        row[a.name] = round cell["final_score"]
        row["#{a.name}_submission_status"] = cell["submission_status"]
        row["#{a.name}_grade_type"] = cell["grade_type"]
        row["#{a.name}_end_at"] = cell["end_at"]
      end

      course.assessment_categories.each do |cat|
        next unless matrix.has_category? cat.id

        key = "#{cat.name}_category_average"
        row[key] = round matrix.category_average(cat.id, cud.id)
      end

      row["course_average"] = round matrix.course_average(cud.id)

      rows << row
    end

    rows
  end

  def regenerate_url
    url_for controller: :gradebooks, action: :invalidate
  end

  def csv_header(matrix, course)
    header = [ "Email", "first_name", "last_name", "Lecture", "Section", "School", "Major", "Year" ]
    course.assessment_categories.each do |cat|
      next unless matrix.has_category? cat.id
      cat.assessments.each do |asmt|
        next unless matrix.has_assessment? asmt.id
        header << asmt.name
      end
      header << "#{cat.name} Average"
    end
    header << "Course Average"

    header
  end

  def formatted_status status
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

        # general info
        row = [ cud.user.email, cud.user.first_name, cud.user.last_name, cud.lecture, cud.section, cud.school, cud.major, cud.year ]

        # assessment status (see AssessmentUserDatum.status), category averages
        course.assessment_categories.each do |cat|
          next unless matrix.has_category? cat.id

          cat.assessments.each do |asmt|
            next unless matrix.has_assessment? asmt.id

            row << formatted_status(matrix.cell(asmt.id, cud.id)["status"])
          end

          row << round(matrix.category_average(cat.id, cud.id))
        end

        # course average
        row << round(matrix.course_average(cud.id))

        # add to csv
        csv << row
      end
    end
  end
end
