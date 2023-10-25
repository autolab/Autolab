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

    // Penalties tab
    $('#unlimited_submissions').on('change', function() {
      const checked = $(this).prop('checked');
      const $max_submissions = $('#assessment_max_submissions');
      $max_submissions.prop('disabled', checked);
      if (checked) {
        $max_submissions.val(-1);
      }
    });

    $('#unlimited_grace_days').on('change', function() {
      const checked = $(this).prop('checked');
      const $max_grace_days = $('#assessment_max_grace_days');
      $max_grace_days.prop('disabled', checked);
      if (checked) {
        $max_grace_days.val('');
      }
    });

    $('#use_default_late_penalty').on('change', function() {
      const checked = $(this).prop('checked');
      const $latePenaltyField = $('#assessment_late_penalty_attributes_value').parent();
      $latePenaltyField.find('input').prop('disabled', checked);
      $latePenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $('#assessment_late_penalty_attributes_value').val('');
      }
    });

    $('#use_default_version_threshold').on('change', function() {
      const checked = $(this).prop('checked');
      const $version_threshold = $('#assessment_version_threshold');
      $version_threshold.prop('disabled', checked);
      if (checked) {
        $version_threshold.val('');
      }
    });

    $('#use_default_version_penalty').on('change', function() {
      const checked = $(this).prop('checked');
      const $versionPenaltyField = $('#assessment_version_penalty_attributes_value').parent();
      $versionPenaltyField.find('input').prop('disabled', checked);
      $versionPenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $('#assessment_version_penalty_attributes_value').val('');
      }
    });

  });

})();


