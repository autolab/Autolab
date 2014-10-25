/*
	Table.js
	Enumerates dynamic tables of class "sortable".
	Adds <th class=enum>#</th> to every row.
*/

/*	Checks if an element is of a given class*/
function hasClass(element, cls) {return (' ' + element.className + ' ').indexOf(' ' + cls + ' ') > -1;}

/*	Renumbers enumerated cells. Useful after sorting table rows.*/
function updatenum(table){
	var rows = table.getElementsByTagName("tr");
	for (var i=0; i<rows.length; i++){
		var el = rows[i].getElementsByTagName("th")[0];
		if (el && hasClass(el, 'enum')){el.innerHTML=i;}
	}
}

/*	Enumerates a table	*/
function enumerate(table){
	table.setAttribute('onclick','updatenum(this);');
	var rows = table.getElementsByTagName("tr");	
	
	/*Defines style for enumerated cells*/
	var style = "style='background-color:#DDD; padding:1px; text-align:center; font-size:10px; color:#444;'";
	for (var i=0; i<rows.length; i++){rows[i].innerHTML = "<th class='enum'" + style + ">"+i+"</td>"+rows[i].innerHTML;}
}

/*	Main function - applies sorting*/
function reapply(){
	/* brokentable() checks if a table has been enumerated or overwritten */
	function brokentable(table){
		var el = table.getElementsByTagName("th")[0];
		return (el && !hasClass(el, 'enum'));}
		
	/* 	Iterate through all sortable tables, and check if
		they are enumerated.  If not, enumerate. */
	var tables = document.getElementsByTagName("table");
	for (var j=0; j<tables.length; j++){
		if (hasClass(tables[j], 'sortable')){
			if (brokentable(tables[j])==true){enumerate(tables[j]);}
		}
	}
	
	/* Check again in case content has changed */
	setTimeout("reapply()",1000);
}

/*reapply();*/
