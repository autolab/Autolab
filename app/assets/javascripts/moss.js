function toggleOptions(dropdownId, tableId) {
  const table = document.getElementById(tableId);
  const dropdown = document.getElementById(dropdownId);
  table.style.display = (table.style.display === "none") ? "block" : "none";
  if (table.style.display === "none") {
    $(dropdown).children('.expand-more').show()
    $(dropdown).children('.expand-less').hide()
  } else {
    $(dropdown).children('.expand-more').hide()
    $(dropdown).children('.expand-less').show()
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