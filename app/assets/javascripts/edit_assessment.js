;(function() {
  // Check for changes before navigating away if there are unsubmitted changes.
  // TODO: This script won't recognize text that has been changed twice
  //       resulting in no net effect to the input.

  var changes = false;

  $(document).ready(function() {

    $('input').on('change', function(e) {
      changes = true;
    });
    $('textarea').on('change', function(e) {
      changes = true;
    });

    $(document).ready(function(){
      $('.tabs').tabs();
    });
    

    window.onbeforeunload = function() {
      if (changes) {
        return 'It looks like you might have unsubmitted changes. Are you sure you want to continue?';
      }
      else {
        return null;
      }
    }

    $('form').on('submit', function() {
      changes = false;
    });

    $('input[name="assessment[is_positive_grading]"]').on('change', function() {
      if(has_annotations){
        if ($(this).prop('checked') !=  is_positive_grading) {
          $('#grading-change-warning').show();
        }
        else{
          $('#grading-change-warning').hide();
        }
      }
    });

  });

})();


