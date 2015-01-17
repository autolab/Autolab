/*
    sorttable.js
    Enables the sorting of tables on a per column basis.
    Sorting is stable and does not modify the elements being
    sorted in any way other than their relative position.

    Usage:
        Give a table the class "sortable" and make sure that
        all of the elements you want sorted are wrapped
        in a <tbody> tag, it will take care
        of the rest. Whenever a user clicks on a particular
        heading, the table will be sorted based on that column.

    Includes the sortElements jQuery plugin:
    https://github.com/padolsey/jQuery-Plugins/blob/master/sortElements/jquery.sortElements.js
*/

/**
 * jQuery.fn.sortElements
 * --------------
 * @author James Padolsey (http://james.padolsey.com)
 * @version 0.11
 * @updated 18-MAR-2010
 * --------------
 * @param Function comparator:
 *   Exactly the same behaviour as [1,2,3].sort(comparator)
 *
 * @param Function getSortable
 *   A function that should return the element that is
 *   to be sorted. The comparator will run on the
 *   current collection, but you may want the actual
 *   resulting sort to occur on a parent or another
 *   associated element.
 *
 *   E.g. $('td').sortElements(comparator, function(){
 *      return this.parentNode;
 *   })
 *
 *   The <td>'s parent (<tr>) will be sorted instead
 *   of the <td> itself.
 */
jQuery.fn.sortElements = (function(){

	var sort = [].sort;

	return function(comparator, getSortable) {

	    getSortable = getSortable || function(){return this;};

	    var placements = this.map(function(){

		    var sortElement = getSortable.call(this),
		    parentNode = sortElement.parentNode,

		    // Since the element itself will change position, we have
		    // to have some way of storing it's original position in
		    // the DOM. The easiest way is to have a 'flag' node:
		    nextSibling = parentNode.insertBefore(
							  document.createTextNode(''),
                    sortElement.nextSibling
							  );

		    return function() {

			if (parentNode === this) {
			    throw new Error(
                        "You can't sort elements if any one is a descendant of another."
					    );
			}

			// Insert before flag:
			parentNode.insertBefore(this, nextSibling);
			// Remove flag:
			parentNode.removeChild(nextSibling);

		    };

		});

	    return sort.call(this, comparator).each(function(i){
		    placements[i].call(getSortable.call(this));
		});

	};
})();

var sorttables = (function($) { return function() {
	$('.sortable').each(function() {

		var $table = $(this);
		$table.find('th').each(function() {
			var $th = $(this);
			var thIndex = $th.index();
			var inverse = false;

			/**
			 * This looks complex and slow (it's both!)
			 * but the underlying concept is simple.
			 *
			 * 1. Anything that jQuery maps to an empty string
			 *    (bad values, non-present nodes, empty strings)
			 *    all ends up at the bottom independent of sort
			 *    order.
			 * 2. Strings always go below numeric values.
			 * 3. Strings are compared alphabetically (after downcasing).
			 * 4. Numbers are compared as you would expect.
			 * 5. The sorting is stable even if the browser's sort
			 *    is not.
			 */
			var comparator = function(nodeA, nodeB) {
				var a = $.trim($(nodeA).text()).toLowerCase();
				var b = $.trim($(nodeB).text()).toLowerCase();
				var result;

				// Deal with invalid values.
				if (!a && !b) {
					return 0;
				} else if (!a) {
					return 1;
				} else if (!b) {
					return -1;
				}

				// Deal with strings.
				else if (!$.isNumeric(a) && !$.isNumeric(b)) {
					result =  a.localeCompare(b);
				} else if (!$.isNumeric(a)) {
					return 1;
				} else if (!$.isNumeric(b)) {
					return -1;
				}

				// Deal with numbers.
				else {
					var valueA = parseFloat(a);
					var valueB = parseFloat(b);
					if (valueA === valueB) {
						result = 0;
					} else if (valueA > valueB) {
						result = 1;
					} else {
						result = -1;
					}
				}

				result = inverse ? -result : result;

				// This is a hack to make sorting stable.
				// The idea is that if the two values are
				// equal, we sort them based on the positions
				// of their table rows.
				if (result === 0) {
					var rowAIndex = $(nodeA).parent().index();
					var rowBIndex = $(nodeB).parent().index();
					if (rowAIndex === -1 && rowBIndex === -1) {
						result = 0;
					} else if (rowAIndex === -1) {
						result = 1;
					} else if (rowBIndex === -1) {
						result = -1;
					} else if (rowAIndex < rowBIndex) {
						result = -1;
					} else {
						result = 1;
					}
				}
				return result;
			};

			// We want to get the <th> associated with the <td>
			// since that's what we want to move.
			var getSortable = function() {
				return this.parentNode;
			};

			$th.click(function(e) {
				var $elements = $table.find('td').filter(function() {
					return $(this).index() === thIndex;
				});
				$elements.sortElements(comparator, getSortable);
				inverse = !inverse;
			});
		});
	});
}})(jQuery);

// Once the DOM has loaded, make the table columns sortable
jQuery(document).ready(function() {
  sorttables();
});
