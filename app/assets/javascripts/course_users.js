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
  if (newTotal > 0) {
    document.getElementById("results-count").innerHTML = newTotal;
  }
  else {
    document.getElementById("results-count").innerHTML = "no";
  }
}

const validateIdentity = (input) => {
  // when input is first name middle name last name <email>
  const regex = /^([a-zA-Z]+)\s([a-zA-Z]+)\s([a-zA-Z]+)\s<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>$/
  if(regex.test(input))
    return true
  
  // when input is first name last name <email>
  const regex2 = /^([a-zA-Z]+)\s([a-zA-Z]+)\s<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>$/
  if(regex2.test(input))
    return true
  
  // when input is first name <email>
  const regex3 = /^([a-zA-Z]+)\s<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>$/
  if(regex3.test(input))
    return true
  
  // when input is email
  const regex4 = /^([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$/
  if(regex4.test(input))
    return true

  return false
};

document.addEventListener('DOMContentLoaded', function () {
  $('#lti-settings-modal').modal({
    dismissible: false,
    preventScrolling: false
  });

  let elem = document.querySelector('#add-users');
  let instance = M.Dropdown.init(elem, {
    constrainWidth: false,
    coverTrigger: false,
    closeOnClick: false,
  });

  // remove keydown event listener for add-users-dropdown
  instance._handleDropdownKeydownBound = function (e) {};

  // Add authentication token to add form
  $('#add-users-dropdown > [name="authenticity_token"]').val($('meta[name="csrf-token"]').attr('content'));

  // form validation
  $("#add-users-submit").click(function (event) {
    let error_free = true;
    let error_message = "";
    
    let inputs = $('[name="user_emails"]').val();
    
    if(inputs.length == 0) {
      error_free = false;
      error_message = "Please enter at least one email address";
    }

    let invalid_inputs = [];
    inputs.split('\n').forEach(function (input) {
      // keep track of invalid inputs  
      if (input.length > 0 && !validateIdentity(input)) {
        error_free = false;
        invalid_inputs.push(input);
      }
    });
    if (invalid_inputs.length > 0) {
      error_message = "Invalid email(s): " + invalid_inputs.join(', ');
    }

    if($('[name="role"]').val() === "" || $('[name="role"]').val() === null) {
      error_free = false;
      error_message = "Please select a role";
    }

    if (!error_free) {
      // make error-box visible & add error message to error-box-text
      $('#error-box').css('display', 'block');
      $('#error-box-text').text(error_message);
      // resize dropdown to fit error-box
      instance.recalculateDimensions();
      event.preventDefault();
    }

  });
});
