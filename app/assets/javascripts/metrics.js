// Loads all Semantic javascripts
//= require semantic-ui
$(document).ready(function(){
    $('.tabular.menu .item').tab();
    $('.ui.dropdown').dropdown();
    $('.ui.checkbox').checkbox();
    $('.ui.form')
	  .form({
	    fields: {
	      percentage: {
	        identifier: 'percentage',
	        optional: 'true',
	        rules: [
	          {
	            type   : 'integer[0..100]',
	            prompt : 'Please enter an integer from 0 to 100 for percentages'
	          }
	        ]
      	  }
	    }
	  })
	;
});
