// Adds addDays function to Date prototype
Date.prototype.addDays = function(days) {
  var date = new Date(this.valueOf());
  date.setDate(date.getDate() + days);
  return date;
}

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

  /* Create all 4 date pickers */
  var grading_deadline_pickr = createDatePicker('#assessment_grading_deadline');
  
  function endAtOnCloseHandler(selected_dates, date_str, flatpickr_inst) {
    var cur_date = selected_dates[0];
    if (grading_deadline_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      grading_deadline_pickr.setDate(cur_date, true);
    }
  }
  
  /* Add custom onClose handler for end at date picker */
  var end_at_pickr = createDatePicker('#assessment_end_at',{onClose:endAtOnCloseHandler});

  function dueAtOnCloseHandler(selected_dates, date_str, flatpickr_inst) {
      var cur_date = selected_dates[0];
      if (grading_deadline_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
        grading_deadline_pickr.setDate(cur_date, true);
      }

      if (end_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
        end_at_pickr.setDate(cur_date, true);
      }
  }

  /* Add custom onClose handler for due at date picker */
  /* Adds 7 days between start_at and end_at */
  var due_at_pickr = createDatePicker('#assessment_due_at', {onClose : dueAtOnCloseHandler});
  const daysBetweenStartEnd = 7;

  function startAtPickronCloseHandler(selected_dates, date_str, flatpickr_inst){
    var cur_date = selected_dates[0];
    
    if (due_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      due_at_pickr.setDate(cur_date.addDays(daysBetweenStartEnd), true);
    }

    if (grading_deadline_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      grading_deadline_pickr.setDate(cur_date.addDays(daysBetweenStartEnd), true);
    }

    if (end_at_pickr.selectedDates[0].getTime() < cur_date.getTime()) {
      end_at_pickr.setDate(cur_date.addDays(daysBetweenStartEnd), true);
    }
  }

  /* Add custom onClose handler for start_at date picker */
  createDatePicker('#assessment_start_at', {onClose: startAtPickronCloseHandler});
})

