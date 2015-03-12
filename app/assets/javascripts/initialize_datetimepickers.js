// Initialize all Bootstrap 3 Datetime Pickers on the page
;(function() {
  function updateDatetimePickers(e) {
    var ourDate = e.date;

    // Harvest data-* attributes describing linked relationships
    var lessThans = $(this).data('dateLessThan');
    var greaterThans = $(this).data('dateGreaterThan');

    function compareDates(dp_id, cmp) {
      if (dp_id) {
        var theirID = '#' + dp_id;
        var theirDateData = $(theirID).data('DateTimePicker');

        // Check whether the other target has been initialized
        if (theirDateData) {
          var theirDate = theirDateData.date();
          $(theirID).data('DateTimePicker').date(cmp(theirDate, ourDate));
        }
      }
    }

    // We are less than (older than) each of these elements
    if (lessThans) {
      lessThans.split(' ').forEach(function(dp_id, idx, arr) {
        compareDates(dp_id, moment.max);
      });
    }

    // We are greater than (younger than) each of these elements
    if (greaterThans) {
      greaterThans.split(' ').forEach(function(dp_id, idx, arr) {
        compareDates(dp_id, moment.min);
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
