// Initialize all Flatpicker Datetime Pickers on the page
;(function() {
  
  $(document).ready(function() {
    var datetimeElts = $('.datetimepicker');
    for (var i = 0; i < datetimeElts.length; i++) {
      $(datetimeElts[i]).flatpickr({
        enableTime: true,
        altInput: true,
        defaultDate: new Date(moment($(datetimeElts[i]).val()))
      })
    }

    var dateElts = $('.datepicker');

    for (var i = 0; i < dateElts.length; i++) {
      $(dateElts[i]).flatpickr({
        altInput: true,
        defaultDate: new Date(moment($(dateElts[i]).val()).format("MMMM D YYYY"))
      })
    }
  });

})();
