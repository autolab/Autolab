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
    function unlimited_submissions_callback() {
      const checked = $(this).prop('checked');
      const $max_submissions = $('#assessment_max_submissions');
      $max_submissions.prop('disabled', checked);
      if (checked) {
        $max_submissions.val('Unlimited submissions');
      } else {
        $max_submissions.val('');
      }
    }
    $('#unlimited_submissions').on('change', unlimited_submissions_callback);

    function unlimited_grace_days_callback() {
      const checked = $(this).prop('checked');
      const $max_grace_days = $('#assessment_max_grace_days');
      $max_grace_days.prop('disabled', checked);
      if (checked) {
        $max_grace_days.val('Unlimited grace days');
      } else {
        $max_grace_days.val('');
      }
    }
    $('#unlimited_grace_days').on('change', unlimited_grace_days_callback);

    function use_default_late_penalty_callback() {
      const checked = $(this).prop('checked');
      const $latePenaltyValue = $('#assessment_late_penalty_attributes_value');
      const $latePenaltyField = $latePenaltyValue.parent();
      $latePenaltyField.find('input').prop('disabled', checked);
      $latePenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $latePenaltyValue.val('Course default');
      } else {
        $latePenaltyValue.val('');
      }
    }
    $('#use_default_late_penalty').on('change', use_default_late_penalty_callback);

    function use_default_version_threshold_callback() {
      const checked = $(this).prop('checked');
      const $version_threshold = $('#assessment_version_threshold');
      $version_threshold.prop('disabled', checked);
      if (checked) {
        $version_threshold.val('Course default');
      } else {
        $version_threshold.val('');
      }
    }
    $('#use_default_version_threshold').on('change', use_default_version_threshold_callback);

    function use_default_version_penalty_callback() {
      const checked = $(this).prop('checked');
      const $versionPenaltyValue = $('#assessment_version_penalty_attributes_value');
      const $versionPenaltyField = $versionPenaltyValue.parent();
      $versionPenaltyField.find('input').prop('disabled', checked);
      $versionPenaltyField.find('select').prop('disabled', checked);
      if (checked) {
        $versionPenaltyValue.val('Course default');
      } else {
        $versionPenaltyValue.val('');
      }
    }
    $('#use_default_version_penalty').on('change', use_default_version_penalty_callback);

    // Trigger on page load
    unlimited_submissions_callback.call($('#unlimited_submissions'));
    unlimited_grace_days_callback.call($('#unlimited_grace_days'));
    use_default_late_penalty_callback.call($('#use_default_late_penalty'));
    use_default_version_threshold_callback.call($('#use_default_version_threshold'));
    use_default_version_penalty_callback.call($('#use_default_version_penalty'));
  });

})();


