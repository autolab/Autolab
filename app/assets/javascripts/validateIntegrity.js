var submitClicked = false

// I'm relying on the fact that onclick is processed before onsubmit
function setSubmitClicked() {
    submitClicked = true
}

function validateIntegrity(clickedElement) {
  var temp = submitClicked
  submitClicked = false

  if (temp) {
      var checkBoxValue = document.getElementById("integrity_checkbox").checked
      if (!checkBoxValue) {
          displayErrorMessage("You must agree to the academic integrity policy.")
          return false
      } else {
          return true
      }
  }
  return true
}

function clearErrorMessage() {
    document.getElementById("submission_error").innerHTML = "";
}

function displayErrorMessage(message) {
    document.getElementById("submission_error").innerHTML = message;
    window.setTimeout(clearErrorMessage, 1400);
}
