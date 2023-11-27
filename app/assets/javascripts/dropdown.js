function toggleOptions(dropdown, table) {
  const $dropdown = $(dropdown);
  const $table = $(table);

  if ($dropdown.length === 0 || $table.length === 0) {
    console.error('Invalid dropdown or table selector provided to toggleOptions');
    return;
  }

  $table.toggle();
  if ($table.is(':hidden')) {
    $dropdown.find('.expand-more').show();
    $dropdown.find('.expand-less').hide();
  } else {
    $dropdown.find('.expand-more').hide();
    $dropdown.find('.expand-less').show();
  }
}
