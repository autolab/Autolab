// Initialize all Materialize Date and Time pickers
;(function() {

  $(document).ready(function() {
    
    function initDateTime(inputElt, timeElt=null) {
      var input = $(inputElt).pickadate({
        selectMonths: true,
        selectYears: 5,
        close: 'DONE',
        format: 'mmmm d, yyyy'
      });
      var datepicker = input.pickadate('picker');
      datepicker.on('close', function(data) {
        console.log("Opening timepicker...", this.get());
        if (timepicker) {
          timepicker.pickatime('show');
        }

      });
      var afterDone = function(e) {
        datepicker.set('select', datepicker.get() + ' ' + timepicker.val());
        datepicker.set('view', datepicker.get() + ' ' + timepicker.val());
        timepicker.val(datepicker.get() + ' ' + timepicker.val());
        console.log("Got this from datepicker: ", datepicker.get() + ' ' + timepicker.val());
      }
      if (timeElt) {
        var timepicker = $(timeElt).pickatime({
          default: '23:59',
          interval: 1,
          autoclose: false,
          twelvehour: true,
          afterDone: afterDone
        });
      }
    }

    var inputElts = $('.datepicker');
    var timeElts = $('.timepicker').hide();

    for (var i = 0; i < inputElts.length; i++) {
      if (timeElts.length == inputElts.length) {
        initDateTime(inputElts[i], timeElts[i]);
      } else {
        initDateTime(inputElts[i])
      }
    }

  });

})();
