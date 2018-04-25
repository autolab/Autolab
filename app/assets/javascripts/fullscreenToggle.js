toggleFullscreen () = {
    var cont = document.getElementById("pageBody");
    if(cont.classList.contains('container')){
      cont.classList.remove('container');
      cont.classList.add('container-fluid');
      var annotationPane = document.getElementById("annotationPaneId");
      annotationPage.classList.remove('col');
      annotationPage.classList.remove('l3');
      var codePane = document.getElementById("codePaneId");
      codePane.classList.remove('col');
      codePane.classList.remove('l9');
    } else{
      cont.classList.remove('container-fluid');
      cont.classList.add('container');
      var annotationPane = document.getElementById("annotationPaneId");
      annotationPage.classList.add('col');
      annotationPage.classList.add('l3');
      var codePane = document.getElementById("codePaneId");
      codePane.classList.add('col');
      codePane.classList.add('l9');

    }
}