class FormBuilderWithDateTimeInput < ActionView::Helpers::FormBuilder
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

  def date_select(name, options = {}, html_options = {})
    existing_date = @object.send(name)
    formatted_date = existing_date.to_date.strftime("%F") if existing_date.present?
    field = text_field(name, :value => formatted_date,
                 :class => "form-control datepicker",
                 :"data-date-format" => "YYYY-MM-DD")
    wrap_field name, field, options[:help_text]
  end

  def datetime_select(name, options = {}, html_options = {})
    existing_time = @object.send(name)
    formatted_time = existing_time.to_time.strftime("%F %I:%M %p") if existing_time.present?
    field = vanilla_text_field(name, :value => formatted_time,
                 :class => "form-control datetimepicker",
                 :"data-date-format" => "YYYY-MM-DD hh:mm A")
    wrap_field name, field, options[:help_text]
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
