;(function() {
    $(document).ready(function () {
        function access_key_callback() {
            const checked = $(this).prop('checked');
            const $access_key_field = $('#autograder_access_key');
            const $access_key_id_field = $('#autograder_access_key_id');
            $access_key_field.prop('disabled', !checked);
            $access_key_id_field.prop('disabled', !checked);
            if (!checked) {
                $access_key_field.val('', checked);
                $access_key_id_field.val('', checked);
            }
        }

        $('#autograder_use_access_key').on('change', access_key_callback);
        access_key_callback.call($('#autograder_use_access_key'));
        
        function initializeEC2Dropdown() {
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
            
            $('#autograder_instance_type').on('change.ec2-instance', function() {
                const selectedInstance = $(this).val();
                console.log('Selected EC2 instance type:', selectedInstance);
                            });
        }
        
        // Initialize the EC2 dropdown functionality
        initializeEC2Dropdown();
    });
})();