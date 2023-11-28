function filterCourses(name) {
  $(".filterableCourse").each(function(i, e) {
    const keywords = name.trim().split(" ");
    const courseName = e.id.toLowerCase();
    let show = keywords.some((k) => {
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
