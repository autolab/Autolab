module AssessmentHelper
  def stats_table(data)
    out =
    '<table class="striped">
       <thead>
         <tr class="red darken-3 white-text">
           <th class="red darken-3 white-text">Problem</th>
           <th class="red darken-3 white-text">Mean</th>
           <th>Median</th>
           <th>StdDev</th>
           <th>Max</th>
           <th>Min</th>
         </tr>
       </thead>
       <tbody>'
    data.each do |(grouper, stats)|
      out += "<tr>"
      out += "<td>#{grouper}</td>"
      out += "<td>#{stats[:mean]}</td>"
      out += "<td>#{stats[:median]}</td>"
      out += "<td>#{stats[:stddev]}</td>"
      out += "<td>#{stats[:max]}</td>"
      out += "<td>#{stats[:min]}</td>"
      out += "</tr>"
    end
    out +=
    '  </tbody>
     </table>'
    out
  end

  def stats_graph(graph_name, type)
    out = "<div id='#{graph_name + type}Div'></div>"
    out
  end

  def aud_special_grade_type?(aud)
    aud.grade_type != AssessmentUserDatum::NORMAL
  end

  def edit_course_url
    url_for controller: :admin,
            action: :editCourse
  end


  def gradesheet_csv(asmt, as_seen_by)
    CSV.generate do |csv|
      # title row with the column names:
      title = ["Submission Time","Email","Total"]
      asmt.problems.each { |problem| title << problem.name }
      title += ["First name", "Last name", "Section", "Lecture"]
      csv << title

      asmt.course.course_user_data.each do |cud|
        # only for students who haven't dropped
        next unless cud.student?
        next if cud.dropped?

        # generate row for user
        csv << csv_row_for(asmt, cud, as_seen_by)
      end
    end
  end

private

  def csv_row_for(asmt, cud, as_seen_by)
    aud = AssessmentUserDatum.get asmt.id, cud.id
    throw "csv_row_for: no AUD for (#{asmt.id}, #{cud.id})" unless aud

    # create csv row with latest submission time and user email (first and second columns)
    submission = aud.latest_submission
    submission_time = submission.nil? ? nil : submission.created_at.in_time_zone.to_s
    row = [submission_time, cud.user.email]

    grade_type = aud.grade_type
    submission_status = aud.submission_status

    # generate score cells of the row
    score_cells = if grade_type == AssessmentUserDatum::NORMAL &&
                     submission_status == :submitted
                    # map from problem id to score for the problem (or nil, if no score exists)
                    problem_scores_map = aud.latest_submission.problems_to_scores

                    # produce ordered list of scores
                    asmt.problems.map do |p|
                      score = problem_scores_map[p.id]
                      score && score.score ? score.score : nil
                    end
                  else
                    Array.new asmt.problems.count
    end

    # add AUD status (see AUD.status method)
    final = aud.status as_seen_by
    row << final

    # add scores to csv row (for scores columns)
    row.concat score_cells
    row += [cud.user.first_name, cud.user.last_name, cud.section, cud.lecture]
    row
  end

  def bulkGrade_cell(cell)
    case cell
    when Hash
      cell[:error] ? cell[:error] : '<i class="material-icons">search</i>'.html_safe
    when NilClass
      '<i class="material-icons">bookmark_border</i>'.html_safe
    else
      cell
    end
  end

  def bulkGrade_cell_class(cell)
    case cell
    when Hash
      cell.include?(:error) ? "error" : ""
    else
      ""
    end
  end
end
