//= require semantic-ui
// Triggered on keyup in the search field
function filterRows(name) {
    var rows = document.getElementsByClassName("user-row"),
        i = 0, L = rows.length, r;
    var newTotal = 0;

    // Filter rows, keep track of number remaining
    while (i < L) {
      r = rows[i++];
      if (r.innerHTML.toLowerCase().indexOf(name.toLowerCase()) != -1) {
        r.style.display = "table-row";
        newTotal++;
      }
      else
        r.style.display = "none";
    }

    // Update "Found ... users" heading
    if(newTotal > 0) {
      document.getElementById("results-count").innerHTML = newTotal;
    }
    else {
      document.getElementById("results-count").innerHTML = "no";
    }
}


document.addEventListener('DOMContentLoaded', function() {
    var elem = document.querySelector('#add-users');
    var instances = M.Dropdown.init(elem, {
        constrainWidth: false,
        coverTrigger: false,
        closeOnClick: false,
    });
    // Add authennication token to add form
    $('#add-users-dropdown > [name="authenticity_token"]').val($('meta[name="csrf-token"]').attr('content'));
});
