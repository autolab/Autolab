$("#sort-status").change(function () {
  var checked = $(this).is(":checked");
  if (checked) {
    $("#unsorted_cuds").hide();
    $("#sorted_cuds").show();
  } else {
    $("#sorted_cuds").hide();
    $("#unsorted_cuds").show();
  }
});
