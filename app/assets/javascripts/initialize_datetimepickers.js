// Initialize all Flatpicker Datetime Pickers on the page
;(function() {
  
  $(document).ready(function() {
    var datetimeElts = $('.datetimepicker');

    for (var i = 0; i < datetimeElts.length; i++) {
      var defaultDate = new Date(moment())
      if ($(datetimeElts[i]).val()) {
        defaultDate = new Date(moment($(datetimeElts[i]).val()))
      }

      $(datetimeElts[i]).flatpickr({
        enableTime: true,
        altInput: true,
        disableMobile: true,
        defaultDate: defaultDate,
        formatDate: (date, format) => {
          return moment(date).format(format);
        },
        parseDate: (datestr, format) => {
          return moment(datestr, format, true).toDate();
        },
      })
    }

    var dateElts = $('.datepicker');

    for (var i = 0; i < dateElts.length; i++) {
      var defaultDate = new Date(moment())
      if ($(dateElts[i]).val()) {
        defaultDate = new Date(moment($(dateElts[i]).val()).format("MMMM D YYYY"))
      }

      $(dateElts[i]).flatpickr({
        altInput: true,
        defaultDate: defaultDate,
        disableMobile: true
      })
    }
  });

})();
