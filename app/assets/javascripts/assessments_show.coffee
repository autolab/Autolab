# On click to 'fake submit' it triggers a click even on file picker
# so that the user can pick the file
$('#handin_show_assessment #fake-submit').click (e)->
	e.preventDefault()
	$("#handin_show_assessment input[type='file']").trigger('click');

# On file pick, we submit the form automatically
$("input[type='file']").change (e)->
	$('#handin_show_assessment #new_submission').submit()
	$("#handin_show_assessment input[type='file']").val("")  # clear for re-selecting the same file

