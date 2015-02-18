class FormBuilderWithDateTimeInput < ActionView::Helpers::FormBuilder
  %w(text_field text_area).each do |method_name|
    # retain access to default textfield, etc. helpers
    alias_method "vanilla_#{method_name}", method_name

    define_method(method_name) do |name, *args|
      options = args.extract_options!

      # add form-control class (for Bootstrap styling) and pass on to Rails
      options[:class] = "form-control #{options[:class]}"
      field = super name, *(args + [ options ])

      wrap_field name, field, options[:help_text], options[:display_name]
    end
  end

  def score_adjustment_input(name, *args)
    options = args.extract_options!

    fields = fields_for name do |f|
      @template.content_tag :div, class: "score-adjustment input-group" do
        (f.vanilla_text_field :value, class: "form-control value") +
        (@template.content_tag :div, class: "input-group-addon" do
          f.select(:kind, { "points" => "points", "%" => "percent" }, {}, { class: "form-control kind input-group-addon" })
        end)
      end
    end

    wrap_field name, fields, options[:help_text]
  end

  def submit(text, *args)
    options = args.extract_options!

    options[:class] = "btn btn-primary #{options[:class]}"

    super text, *(args + [ options ])
  end

  def check_box(name, *args)
    options = args.extract_options!

    display_name = options[:display_name]

    field = super name, *(args + [ options ])

    @template.content_tag :div, class: "form-group" do
       field + label(name, display_name, class: "control-label") +
          help_text(name, options[:help_text])
    end
  end

  def date_select(name, options = {}, html_options = {})
    strftime = "%F"
    date_format = "YYYY-MM-DD"
    date_helper name, options, strftime, date_format
  end

  def datetime_select(name, options = {}, html_options = {})
    strftime = "%F %I:%M %p"
    date_format = "YYYY-MM-DD hh:mm A"
    date_helper name, options, strftime, date_format
  end

private
  # Pass space-delimited list of IDs of datepickers on the :less_than and
  # :greater_than properties to initialize relationships between datepicker
  # fields.
  def date_helper name, options, strftime, date_format
    existing_time = @object.send(name)
    formatted_datetime = existing_time.to_time.strftime(strftime) if existing_time.present?

    field = vanilla_text_field(name, :value => formatted_datetime,
        :class => "form-control datetimepicker",
        :"data-date-format" => date_format,
        :"data-date-less-than" => options[:less_than],
        :"data-date-greater-than" => options[:greater_than])

    wrap_field name, field, options[:help_text]
  end

  def wrap_field name, field, help_text, display_name=nil
    @template.content_tag :div, class: "form-group" do
      label(name, display_name, class: "control-label") + field + help_text(name, help_text)
    end
  end

  def help_text(name, help_text)
    @template.content_tag :p, help_text, class: "help-block"
  end

  def objectify_options options
    super.except :help_text
  end

end
