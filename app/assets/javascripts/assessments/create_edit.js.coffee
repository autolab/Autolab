$(->
  checkbox = $("#assessment_disable_handins")
  checkbox.change -> $("div#handin").toggle 100
)
