;
(function() {
    $(function() {
        const $useAccessKeyCheckbox = $('#autograder_use_access_key');
        const $accessKeyField = $('#autograder_access_key');
        const $accessKeyIdField = $('#autograder_access_key_id');

        function toggleAccessKeyFields() {
            const checked = $useAccessKeyCheckbox.prop('checked');
            $accessKeyField.prop('disabled', !checked);
            $accessKeyIdField.prop('disabled', !checked);

            if (!checked) {
                $accessKeyField.val('');
                $accessKeyIdField.val('');
            }
        }

        $useAccessKeyCheckbox.on('change', toggleAccessKeyFields);
        toggleAccessKeyFields();

        if ($.fn.tooltip) {
            $('.browser-default[data-tooltip]').tooltip({
                enterDelay: 300,
                exitDelay: 200,
                position: 'top'
            });
        }

        $('#autograder_instance_type option').hover(
            function() { $(this).addClass('highlighted-option'); },
            function() { $(this).removeClass('highlighted-option'); }
        );
    });
})();