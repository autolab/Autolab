// Initialize all Bootstrap 3 Datetime Pickers on the page
;(function() {
  
  $(document).ready(function() {
    var datetimeElts = $('.datetimepicker');
    for (var i = 0; i < datetimeElts.length; i++) {
      $(datetimeElts[i]).flatpickr({
        enableTime: true,
        altInput: true,
        defaultDate: moment($(datetimeElts[i]).val()).format("MMMM D YYYY, h:mm A")
      })
    }

    var dateElts = $('.datepicker');

    for (var i = 0; i < dateElts.length; i++) {
      $(dateElts[i]).flatpickr({
        altInput: true,
        defaultDate: moment($(dateElts[i]).val()).format("MMMM D YYYY")
      })
    }
  });

})();
