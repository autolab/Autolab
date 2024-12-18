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
    result
  end

  def processStackDump(dump)
    dump.delete_if do |line|
      line.start_with?("/usr/local/lib/ruby")
    end
  end

  def roundValue(val)
    if val.is_a?(Float) && val.nan?
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
    editor_mode_options.transpose[1]
  end

  def editor_mode_names
    editor_mode_options.transpose[0]
  end

  def editor_mode_options
    [
      ["C/C++", "c_cpp"],
      ["C#", "csharp"],
      %w(CSS css),
      %w(HTML html),
      %w(Java java),
      %w(JavaScript javascript),
      %w(LaTeX latex),
      %w(Lisp clojure),
      %w(Perl perl),
      %w(PHP php),
      %w(Python python),
      %w(Ruby ruby),
      %w(Scala scala),
      ["SML/OCaml", "ocaml"],
      %w(SQL sql),
      %w(Text text),
      %w(XML xml)
    ]
  end

  def download_file(submission, title)
    link_to title, download_course_assessment_submission_path(@course, @assessment, submission),
            tabindex: -1, target: "_blank"
  end

  def download_file_url(submission)
    download_course_assessment_submission_path(@course, @assessment, submission)
  end

  def view_syntax_highlighted_source(submission, title)
    if submission.syntax?
      link_to title, view_course_assessment_submission_path(@course, @assessment, submission),
              tabindex: -1, target: "_blank"
    end
  end

  def view_archive_files(submission, title)
    if Archive.archive? submission.handin_file_path
      link_to title, url_for([:view, @course, @assessment, submission]),
        tabindex: -1, target: "_blank"
    end
  end

  def view_file(submission, view_archive_title, view_source_title, download_title = nil)
    if (link = view_archive_files(submission, view_archive_title))
      link
    elsif (link = view_syntax_highlighted_source(submission, view_source_title))
      link
    elsif download_title
      download_file(submission, download_title)
    end
  end

  def go_img(vertical_align)
    image_tag("/images/go.png", style: "vertical-align: %dpx" % vertical_align)
  end

  def sections(_course)
    CourseUserDatum.count(:all, group: "section")
  end

  # TODO: fix during gradebook, handin history, etc. rewrite
  def computed_score(link = nil, nil_to_dash = true)
    value = yield
    value = value ? value.round(1) : value
    nil_to_dash && (value.nil?) ? raw("&ndash;") : value
  rescue ScoreComputationException => e
    image = image_tag("score_error.png", style: "width: 1.3em; height: 1.3em")
    (@cud.instructor? && link) ? link_to(image, link) : image
  end

  def round(v)
    v ? v.round(1) : v
  end

  # NOTE: aud.final_score cannot be nil in here
  def render_final_score(aud)
    asmt = aud.assessment

    fs = computed_score(history_url(@_cud, asmt), false) { aud.final_score @cud }
    fail "FATAL: can't be nil" unless fs

    link = link_to fs, history_url(@_cud, asmt)

    max_score = computed_score { asmt.max_score }
    max_score_s = '<span class="max_score">' + max_score.to_s + "</span>"

    raw("#{link}/#{max_score_s}")
  end

  # TODO: fix when rewriting handin history/student gradebook
  def ignored_submission_style(s)
    "text-decoration: " + (s.ignored? ? "line-through" : "none") + ";"
  end

  def external_stylesheet_link_tag(library)
    cloudflare = "//cdnjs.cloudflare.com/ajax/libs"

    # Update versions manually as-and-when newer versions become available on the CDN
    case library
    when "jquery-ui"
      version = "1.13.2"
      stylesheet_link_tag "#{cloudflare}/jqueryui/#{version}/themes/smoothness/jquery-ui.min.css"
    when "flatpickr"
      version = "4.6.13"
      stylesheet_link_tag "#{cloudflare}/flatpickr/#{version}/flatpickr.min.css"
    when "golden-layout-base"
      version = "1.5.9" # latest is "2.6.0"
      stylesheet_link_tag "#{cloudflare}/golden-layout/#{version}/css/goldenlayout-base.css"
    when "golden-layout-theme"
      version = "1.5.9" # latest is "2.6.0"
      stylesheet_link_tag "#{cloudflare}/golden-layout/#{version}/css/goldenlayout-light-theme.css"
    when "semantic-ui"
      version = "2.5.0"
      stylesheet_link_tag "#{cloudflare}/semantic-ui/#{version}/semantic.min.css"
    when "diff2html"
      stylesheet_link_tag "//cdn.jsdelivr.net/npm/diff2html/bundles/css/diff2html.min.css"
    end
  end

  def external_javascript_include_tag(library)
    cloudflare = "//cdnjs.cloudflare.com/ajax/libs"

    # Update versions manually as-and-when newer versions become available on the CDN
    case library
    when "jquery"
      version = "3.7.1"
      javascript_include_tag "#{cloudflare}/jquery/#{version}/jquery.min.js"
    when "jquery-migrate"
      # Added for compatibility since we are migrating from jquery 2.2.4
      # Remove once there are no more warnings
      version = "3.4.1"
      javascript_include_tag "#{cloudflare}/jquery-migrate/#{version}/jquery-migrate.js"
    when "jquery-ui"
      version = "1.13.2"
      javascript_include_tag "#{cloudflare}/jqueryui/#{version}/jquery-ui.min.js"
    when "lodash"
      version = "3.10.1" # latest is "4.17.21"
      javascript_include_tag "#{cloudflare}/lodash.js/#{version}/lodash.min.js"
    when "jquery.dataTables"
      version = "1.13.4"
      javascript_include_tag "https://cdn.datatables.net/#{version}/js/jquery.dataTables.min.js"
    when "flatpickr"
      version = "4.6.13"
      javascript_include_tag "#{cloudflare}/flatpickr/#{version}/flatpickr.min.js"
    when "scrollTo"
      version = "2.1.3"
      javascript_include_tag "#{cloudflare}/jquery-scrollTo/#{version}/jquery.scrollTo.min.js"
    when "golden-layout"
      version = "1.5.9" # latest is "2.6.0"
      javascript_include_tag "#{cloudflare}/golden-layout/#{version}/goldenlayout.min.js"
    when "semantic-ui-accordion"
      version = "2.5.0"
      javascript_include_tag "#{cloudflare}/semantic-ui/#{version}/components/accordion.min.js"
    when "clipboardjs"
      version = "2.0.11"
      javascript_include_tag "#{cloudflare}/clipboard.js/#{version}/clipboard.min.js"
    when "diff2html"
      javascript_include_tag "//cdn.jsdelivr.net/npm/diff2html/bundles/js/diff2html-ui.min.js"
    end
  end

  def history_url(cud, asmt = @assessment)
    history_course_assessment_path(@course, asmt, cud_id: cud.id)
  end
end
