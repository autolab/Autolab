function toggleOptions(dropdown, table) {
  const $dropdown = $(dropdown);
  const $table = $(table);

  $table.toggle();
  if ($table.is(':hidden')) {
    $dropdown.children('.expand-more').show();
    $dropdown.children('.expand-less').hide();
  } else {
    $dropdown.children('.expand-more').hide();
    $dropdown.children('.expand-less').show();
  }
}
