# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # Helpers for Rails 4 REST API Paths
  def current_assessment_path
    course_assessment_path(@course, @assessment)
  end

  def current_assessment_link
    link_to @assessment.display_name, course_assessment_path(@course, @assessment)
  end

  # Older Helpers
  def sort_td_class_helper(param)
    result = 'class="sortup"' if params[:sort] == param
    result = 'class="sortdown"' if params[:sort] == param + " DESC"
    return result
  end

  def processStackDump(dump)
    dump.delete_if{ |line|
      line.start_with?("/usr/local/lib/ruby")
    }
  end

  def roundValue(val)
    if val.is_a? Float and val.nan? then
      return val
    elsif val.is_a? Numeric
      return val.to_f.round(1)
    else
      return val
    end
  end

  def tweak(tweak)
    tweak ? tweak.to_s : "&ndash;"
  end

  def editor_modes
    self.editor_mode_options.transpose[1]
  end

  def editor_mode_names
    self.editor_mode_options.transpose[0]
  end

  def editor_mode_options
    [
      ['C/C++', 'c_cpp'],
      ['C#', 'csharp'],
      ['CSS', 'css'],
      ['HTML', 'html'],
      ['Java', 'java'],
      ['JavaScript', 'javascript'],
      ['LaTeX', 'latex'],
      ['Lisp', 'clojure'],
      ['Perl', 'perl'],
      ['PHP', 'php'],
      ['Python', 'python'],
      ['Ruby', 'ruby'],
      ['Scala', 'scala'],
      ['SML/OCaml', 'ocaml'],
      ['SQL', 'sql'],
      ['Text', 'text'],
      ['XML', 'xml']
    ]
  end

  def download_file(submission, title)
    link_to title, download_course_assessment_submission_path(@course, @assessment, submission),
            :tabindex => -1, :target => "_blank"
  end


  def download_file_url(submission)
    download_course_assessment_submission_path(@course, @assessment, submission)
  end


  def view_syntax_highlighted_source(submission, title)
    if submission.is_syntax
      link_to title, view_course_assessment_submission_path(@course, @assessment, submission),
              :tabindex => -1, :target => "_blank"
    end
  end

  def view_syntax_highlighted_source_url(submission)
    if submission.is_syntax
      view_course_assessment_submission_path(@course, @assessment, submission)
    end
  end

  def list_archive_files(submission, title)
    if submission.is_archive
      link_to title, list_archive_course_assessment_submission_path(@course, @assessment, submission),
        :tabindex => -1, :target => "_blank"
    end
  end

  def view_file(submission, list_archive_title, view_source_title, download_title = nil)
    if (link = list_archive_files(submission, list_archive_title))
      link
    elsif (link = view_syntax_highlighted_source(submission, view_source_title))
      link
    elsif (download_title)
      download_file(submission, download_title)
    end
  end

  def go_img(vertical_align)
    return image_tag("/images/go.png", style: "vertical-align: %dpx" % vertical_align)
  end

  def sections(course)
    CourseUserDatum.count(:all, :group => 'section');
  end

  # TODO: fix during gradebook, handin history, etc. rewrite
  def computed_score(link = nil, nil_to_dash = true)
    begin
      # if non-nil, round value; otherwise, --
      value = yield
      value = value ? value.round(1) : value
      nil_to_dash && (value == nil) ? raw("&ndash;") : value
    rescue ScoreComputationException => e
      image = image_tag("score_error.png", :style => "width: 1.3em; height: 1.3em")
      (@cud.instructor? and link) ? link_to(image, link) : image
    end
  end

  def round(v)
    v ? v.round(1) : v
  end

  # NOTE: aud.final_score cannot be nil in here
  def render_final_score(aud)
    asmt = aud.assessment

    fs = computed_score(history_url(@_cud, asmt), false) { aud.final_score @cud }
    raise "FATAL: can't be nil" unless fs
    if @cud.student?
      link = link_to fs, history_url(@_cud, asmt)
    else
      link = link_to fs, :assessment => asmt.name, :action => :student
    end

    max_score = computed_score { asmt.max_score }
    max_score_s = '<span class="max_score">' + max_score.to_s + '</span>'

    raw("#{link}/#{max_score_s}")
  end

  # TODO: fix when rewriting handin history/student gradebook
  def ignored_submission_style(s)
    "text-decoration: " + (s.ignored? ? "line-through" : "none") + ";"
  end

  def external_stylesheet_link_tag(library, version)
    cloudflare = "//cdnjs.cloudflare.com/ajax/libs"
    case library
    when 'bootstrap'
      stylesheet_link_tag "#{cloudflare}/twitter-bootstrap/#{version}/css/bootstrap.css"
    end
  end

  def external_javascript_include_tag(library, version)
    cloudflare = "//cdnjs.cloudflare.com/ajax/libs"
    google = "//ajax.googleapis.com/ajax/libs"

    case library
    when 'jquery'
      javascript_include_tag "#{google}/jquery/#{version}/jquery.min.js"
    when 'jquery-ui'
      javascript_include_tag "#{google}/jqueryui/#{version}/jquery-ui.min.js"
    when 'prototype'
      javascript_include_tag "#{google}/prototype/#{version}/prototype.js"
    when 'lodash'
      javascript_include_tag "#{cloudflare}/lodash.js/#{version}/lodash.min.js"
    when 'backbone'
      javascript_include_tag "#{cloudflare}/backbone.js/#{version}/backbone-min.js"
    when 'backbone-relational'
      javascript_include_tag "#{cloudflare}/backbone-relational/#{version}/backbone-relational.min.js"
    when 'jquery.dataTables'
      javascript_include_tag "#{cloudflare}/datatables/#{version}/jquery.dataTables.min.js"
    when 'handlebars'
      javascript_include_tag "#{cloudflare}/handlebars.js/#{version}/handlebars.min.js"
    when 'bootstrap'
      javascript_include_tag "#{cloudflare}/twitter-bootstrap/#{version}/js/bootstrap.js"
    when 'bootstrap-tooltip'
      javascript_include_tag "#{cloudflare}/twitter-bootstrap/#{version}/js/bootstrap-tooltip.js"
    end
  end

  def history_url(cud, asmt = @assessment)
    history_course_assessment_path(@course, asmt, cud_id: cud.id)
  end

end
