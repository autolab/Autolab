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

function filterCourses(name) {
  $(".filterableCourse").each(function(i, e) {
    const keywords = name.split(" ");
    const courseName = e.id.toLowerCase();
    let show = keywords.every((k) => {
      return courseName.includes(k);
    });
    $(e).toggle(show);
  });
}

$(document).ready(function() {
  const $courseFilter = $("#courseFilter");
  $courseFilter.on("keyup", function() {
    filterCourses(this.value.toLowerCase());
  });
  $courseFilter.trigger("keyup");
});
