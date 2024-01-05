// Initialize all Flatpicker Datetime Pickers on the page

$(document).ready(function() {

  function createDatePicker(selector, config) {   
    var elt = $(selector)
    var defaults = {
      enableTime: true,
      altInput: true,
      disableMobile: true,
      defaultDate: moment(elt.val(), elt.data("date-format")).toDate(),
      parseDate: (datestr, format) => {
        return moment(datestr, format, true).toDate();
      },
      formatDate: (date, format) => {
        return moment(date).format(format);
      },
    }
    Object.assign(defaults, config);
    /* Invoke flatpickr library */
    return flatpickr(selector, defaults)
  }
  
  /* Add custom onClose handler for end at date picker */
  var end_at_pickr = createDatePicker('#assessment_end_at');

  function dueAtOnCloseHandler(selected_dates, date_str, flatpickr_inst) {
      var cur_date = selected_dates[0];

      if (end_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
        end_at_pickr.setDate(cur_date, true);
      }
  }

  /* Add custom onClose handler for due at date picker */
  var due_at_pickr = createDatePicker('#assessment_due_at', {onClose : dueAtOnCloseHandler});

  function startAtPickronCloseHandler(selected_dates, date_str, flatpickr_inst){
    var cur_date = selected_dates[0];
    
    if (due_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      due_at_pickr.setDate(cur_date, true);
    }

    if (end_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      end_at_pickr.setDate(cur_date, true);
    }
  }

  /* Add custom onClose handler for start_at date picker */
  createDatePicker('#assessment_start_at', {onClose: startAtPickronCloseHandler});
})

