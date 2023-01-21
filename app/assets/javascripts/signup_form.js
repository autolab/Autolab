document.addEventListener('DOMContentLoaded', () => {
  // Ensures that only one of [first name, last name] is required.
  const inputFirstName = document.getElementById("user_first_name");
  const inputLastName = document.getElementById("user_last_name");

  const updateRequiredInputs = () => {
    inputFirstName.required = !inputLastName.value.length;
    inputLastName.required = !inputFirstName.value.length;
  }
  updateRequiredInputs();
  inputFirstName.addEventListener('input', updateRequiredInputs);
  inputLastName.addEventListener('input', updateRequiredInputs);

  // Pre-validates the password confirmation field. 
  const inputPassword = document.getElementById("user_password");
  const inputPasswordConfirm = 
    document.getElementById("user_password_confirmation");

  const updatePasswordConfirmPattern = () => {
    if (inputPassword.checkValidity()) 
      inputPasswordConfirm.pattern = inputPassword.value;
    else 
      inputPasswordConfirm.removeAttribute('pattern');
  }
  inputPassword.addEventListener('input', updatePasswordConfirmPattern);
});

