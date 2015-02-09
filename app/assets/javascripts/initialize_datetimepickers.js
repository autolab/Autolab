// Initialize all Bootstrap 3 Datetime Pickers on the page
;(function() {
  function updateDatetimePickers(e) {
    var ourDate = e.date;

    // Harvest data-* attributes describing linked relationships
    var lessThans = $(this).data('dateLessThan');
    var greaterThans = $(this).data('dateGreaterThan');

    // We are less than (older than) each of these elements
    if (lessThans) {
      lessThans.split(' ').forEach(function(dp_id, idx, arr) {
        if (dp_id) {
          var theirID = '#' + dp_id;
          var theirDate = $(theirID).data('DateTimePicker').date();

          $(theirID).data('DateTimePicker').date(moment.max(theirDate, ourDate));
        }
      });
    }

    // We are greater than (younger than) each of these elements
    if (greaterThans) {
      greaterThans.split(' ').forEach(function(dp_id, idx, arr) {
        if (dp_id) {
          var theirID = '#' + dp_id;
          var theirDate = $(theirID).data('DateTimePicker').date();

          $(theirID).data('DateTimePicker').date(moment.min(theirDate, ourDate));
        }
      });
    }
  }

  $(document).ready(function() {
    $('.datetimepicker').each(function(idx) {
      $(this).datetimepicker({
        showTodayButton: true,
        icons: {
          time: 'glyphicon glyphicon-time time-btn',
          date: 'glyphicon glyphicon-calendar date-btn',
          today: 'glyphicon glyphicon-screenshot now-btn'
        }
      });
    });

    $('.datetimepicker').on('dp.change', updateDatetimePickers);
  });
})();
