// Initialize all Bootstrap 3 Datetimepickers on the page
$(document).ready(function() {
  $('.datetimepicker').datetimepicker({
    showTodayButton: true,
    icons: {
      time: 'glyphicon glyphicon-time time-btn',
      date: 'glyphicon glyphicon-calendar date-btn',
      today: 'glyphicon glyphicon-screenshot now-btn'
    }
  });
});
