
/* Highlights lines longer than 80 characters autolab red color */
var highlightLines = function(highlight) {
  $("#code-list > li > code").each(function() {
    var text = $(this).text();
    // To account for lines that have 80 characters and a line break
    var diff = text[text.length - 1] === "\n" ? 1 : 0;
    if(text.length - diff > 80 && highlight){
      $(this).css("background-color", "rgba(153, 0, 0, .9)");
      $(this).prev().css("background-color", "rgba(153, 0, 0, .9)");
    } else {
      $(this).css("background-color", "white");
      $(this).prev().css("background-color", "white");
    }
  });
};

$("#highlightLongLines").click(function(){
  highlightLines(this.checked);
});