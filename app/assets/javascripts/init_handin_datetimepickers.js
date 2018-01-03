// Initialize all Flatpicker Datetime Pickers on the page

$(document).ready(function() {

  function createDatePicker(selector, config) {   
    var elt = $(selector)
    var defaults = {
      enableTime: true,
      altInput: true,
      defaultDate: new Date(moment(elt.val()))
    }
    Object.assign(defaults, config);
    /* Invoke flatpickr library */
    return flatpickr(selector, defaults)
  }

  /* Create all 3 date pickers */
  createDatePicker('#assessment_start_at')
  var end_at_pickr = createDatePicker('#assessment_end_at')
  var grading_deadline_pickr = createDatePicker('#assessment_grading_deadline')

  function onCloseHandler(selected_dates, date_str, flatpickr_inst) {
      var cur_date = selected_dates[0]
      if (grading_deadline_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
        grading_deadline_pickr.setDate(cur_date, true);
      }

      if (end_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
        end_at_pickr.setDate(cur_date, true);
      }

  }
  /* Add custom onClose handler for due at date picker */
  var due_at_pickr = createDatePicker('#assessment_due_at', {onClose : onCloseHandler})

})

