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

    $('#assessment_config_file').on('change', function () {
      var fileSelector = $("#assessment_config_file").get(0);
      var file = fileSelector.files[0];

      if (!file?.name?.endsWith('.rb')) {
        $('#config-file-type-incorrect').text(`Warning: ${file.name} doesn't match expected .rb file type`)
      } else {
        $('#config-file-type-incorrect').text("")
      }
    })

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
    let initial_load = true; // determines if the page is loading for the first time, if so, don't clear the fields

    $('#unlimited_submissions').on('change', function() {
      const checked = $(this).prop('checked');
      const $max_submissions = $('#assessment_max_submissions');
      $max_submissions.prop('disabled', checked);
      if (checked) {
        $max_submissions.val('Unlimited submissions');
      } else if (!initial_load) {
        $max_submissions.val('');
      }
    });

    $('#unlimited_grace_days').on('change', function() {
      const checked = $(this).prop('checked');
      const $max_grace_days = $('#assessment_max_grace_days');
      $max_grace_days.prop('disabled', checked);
      if (checked) {
        $max_grace_days.val('Unlimited grace days');
      } else if (!initial_load) {
        $max_grace_days.val('');
      }
    });

    $('#use_default_late_penalty').on('change', function() {
      const checked = $(this).prop('checked');
      const $latePenaltyValue = $('#assessment_late_penalty_attributes_value');
      const $latePenaltyField = $latePenaltyValue.parent();
      $latePenaltyField.find('input').prop('disabled', checked);
      $latePenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $latePenaltyValue.val('Course default');
      } else if (!initial_load) {
        $latePenaltyValue.val('');
      }
    });

    $('#use_default_version_threshold').on('change', function() {
      const checked = $(this).prop('checked');
      const $version_threshold = $('#assessment_version_threshold');
      $version_threshold.prop('disabled', checked);
      if (checked) {
        $version_threshold.val('Course default');
      } else if (!initial_load) {
        $version_threshold.val('');
      }
    });

    $('#use_default_version_penalty').on('change', function() {
      const checked = $(this).prop('checked');
      const $versionPenaltyValue = $('#assessment_version_penalty_attributes_value');
      const $versionPenaltyField = $versionPenaltyValue.parent();
      $versionPenaltyField.find('input').prop('disabled', checked);
      $versionPenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $versionPenaltyValue.val('Course default');
      } else if (!initial_load) {
        $versionPenaltyValue.val('');
      }
    });

    // Trigger on page load
    $('#unlimited_submissions').trigger('change');
    $('#unlimited_grace_days').trigger('change');
    $('#use_default_late_penalty').trigger('change');
    $('#use_default_version_threshold').trigger('change');
    $('#use_default_version_penalty').trigger('change');
    initial_load = false;
  });

})();


