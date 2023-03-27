$(document).ready(function() {
  const checkboxes = document.querySelectorAll('.cbox');

  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('change', function() {
      const row = checkbox.closest('.course-field');

      if (checkbox.checked) {
        row.classList.add('checked');
      } else {
        row.classList.remove('checked');
      }
    });
  });

  $('#select_all_btn').on('click', function() {
    var fields = document.getElementsByClassName('cbox');
    for(var i=0; i < fields.length; i++){  
      fields[i].checked=true;  
    }  
  });
});