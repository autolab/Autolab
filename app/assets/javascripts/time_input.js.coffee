###

Autolab Time Input 0.0.1 is a jQuery plugin that adds time validation to textfields using Moment.js

Usage:
  <script src="moment.js" type="text/javascript">
  <input type="text" data-provide="time">

For good UX, make sure the input has an existing valid time on page load.

Tom (tomabuct@me.com)

###

(($) ->
  TIME_FORMAT = "h:mm A"

  $.fn.time_input = ->
    this.filter('input').focus ->
      value = $(this).val()

      # set value to blank, if current value isn't valid
      value = "" unless is_valid value

      # save value as previous_value
      $(this).data('previous_value', value);

    this.filter('input').change ->
      value = $(this).val()

      # set value to previous value, if current value isn't valid
      value = $(this).data('previous_value') unless is_valid value

      $(this).val formatted value

  is_valid = (s) ->
    moment(s, TIME_FORMAT).isValid()

  formatted = (s) ->
    m = moment(s, TIME_FORMAT)
    if m.isValid() then m.format(TIME_FORMAT) else null

  # make inputs with data-provide="time" time inputs!
  $(-> $('input[data-provide="time"]').time_input())

)(jQuery)
