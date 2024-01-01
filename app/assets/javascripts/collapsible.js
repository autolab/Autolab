function toggleAria(id) {
  let expanded = document.getElementById(id).getAttribute("aria-expanded");
  if (expanded === "true") {
    expanded = "false"
  } else {
    expanded = "true"
  }
  document.getElementById(id).setAttribute("aria-expanded", expanded);
}

$(document).ready(function(){
  $('.collapsible').collapsible();
});