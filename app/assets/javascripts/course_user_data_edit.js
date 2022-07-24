function formvalidation(form){
    function DoubleByte(str) {
      for (var i = 0, n = str.length; i < n; i++) {
        if (str[i].charCodeAt() > 127) { return true; }
      }
      return false;
    }
    var formlog = 'Your nickname ';
    function flag(msg, nickname){
      nickname.setAttribute('style','background-color:#FFF352');
      if (formlog!= 'Your nickname '){formlog+=' and ';}
      formlog +=msg;

      nickname.focus();
    }
    var nickname = document.getElementById('user_nickname');
    var approve = true;

    if (nickname.value.length>20){approve = false; flag('is too long',nickname);}
    if (DoubleByte(nickname.value)===true){approve = false; flag('has non-ASCII characters',nickname);}

    if (approve){
      form.submit();
    } else {
      alert(formlog);
    }
}

function disable_dropped(){
    $('#course_user_datum_dropped').prop("checked",false);
    $('#course_user_datum_dropped').prop("disabled",true);
}

function enable_dropped(){
    $('#course_user_datum_dropped').prop("disabled",false);
}

function prevent_dropping_instructor_ca(){
    if($('#course_user_datum_instructor').is(':checked') || 
        $('#course_user_datum_course_assistant').is(':checked')){
        disable_dropped();
    }
    else{
        enable_dropped();
    }
}

$(document).ready(prevent_dropping_instructor_ca);

$('#course_user_datum_instructor').on( "click", 
    prevent_dropping_instructor_ca);

$('#course_user_datum_course_assistant').on( "click", 
    prevent_dropping_instructor_ca);
