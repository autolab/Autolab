function addChecked(checkbox) {
  const row = checkbox.closest('.course-field');

  if (checkbox.checked) {
    row.classList.add('checked');
  } else {
    row.classList.remove('checked');
  }
}

$(document).ready(function() {
  const checkboxes = document.querySelectorAll('.cbox');

  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('change', function() {
      addChecked(checkbox);
    });
  });
});
