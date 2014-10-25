class FormBuilderWithDateTimeInput < ActionView::Helpers::FormBuilder
  def datetime_input(name, *args)
    options = args.extract_options!

    # get the DateTime backing this field (this is like assessment.start_at)
    datetime = object.send name

    # generate datetime_input field
    datetime_input_field = @template.content_tag :div do
      date = @template.text_field_tag "#{object_name}[#{name}][date]", datetime.strftime("%m/%d/%Y"),
                               { data: { provide: "datepicker" }, class: "datepicker form-control" }
      time = @template.text_field_tag "#{object_name}[#{name}][time]", datetime.strftime("%l:%M %p").strip,
                               { data: { provide: "time" }, class: "time_input form-control" }

      "#{date} #{time}".html_safe
    end

    wrap_field name, datetime_input_field, options[:help_text]
  end

  %w(text_field text_area).each do |method_name|
    # retain access to default textfield, etc. helpers
    alias_method "vanilla_#{method_name}", method_name

    define_method(method_name) do |name, *args|
      options = args.extract_options!

      # add form-control class (for Bootstrap styling) and pass on to Rails
      options[:class] = "form-control #{options[:class]}"
      field = super name, *(args + [ options ])

      wrap_field name, field, options[:help_text]
    end
  end

  def score_adjustment_input(name, *args)
    options = args.extract_options!

    fields = fields_for name do |f|
      @template.content_tag :div, class: "score-adjustment" do
        c = f.vanilla_text_field :value, class: "form-control value"
        c + f.select(:kind, { "points" => "points", "%" => "percent" }, {}, { class: "form-control kind" })
      end
    end

    wrap_field name, fields, options[:help_text]
  end

  def submit(text, *args)
    options = args.extract_options!

    options[:class] = "btn btn-primary #{options[:class]}"

    super text, *(args + [ options ])
  end

private
  def wrap_field name, field, help_text
    @template.content_tag :div, class: "form-group" do
      label(name, class: "control-label") + field + help_text(name, help_text)
    end
  end

  def help_text(name, help_text)
    @template.content_tag :p, help_text, class: "help-block"
  end

  def objectify_options options
    super.except :help_text
  end

end
