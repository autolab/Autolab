var start = new Date();

var ROW_HEIGHT = 36;
var MAX_GRADEBOOK_HEIGHT = 600;
var grid;
var sort_column = "title";

var slickgrid_options = {
  enableCellNavigation: true,
  enableColumnReorder: false,
  rowHeight: ROW_HEIGHT,
  defaultColumnWidth: 65,
  syncColumnCellResize: true,
  fullWidthRows: true,
  enableTextSelectionOnCells: true,

  defaultFormatter: function(row, cell, value, columnDef, data) {
    user = data.email;
    asmt = columnDef.name;

    submission_status_key = columnDef.field + "_submission_status"
    grade_type_key = columnDef.field + "_grade_type"
    end_at_key = columnDef.field + "_end_at"
    history_key = columnDef.field + "_history_url";

    switch (data[grade_type_key]) {
    case "excused":
      if (options.render_excused_grade_type) {
        tip = user + ' has been excused from ' + asmt + '.';
        value = '<span data-tooltip="' + tip + '" class="tooltipped excused label label-info">Excused</span>';
      }
      break;

    case "zeroed":
      if (options.render_zeroed_grade_type) {
        tip = user + '\'s final score on ' + asmt + ' has been zeroed out.';
        value = '<span data-tooltip="' + tip + '" class="tooltipped zeroed">' + value + '</span>';
      }
      break;

    case "normal":
      switch (data[submission_status_key]) {
      case "submitted":
        break;

      case "not_submitted":
        tip = user + ' has not made any submissions for ' + asmt + '. <br>';
        tip += 'The last date for submission by ' + user + ' was ' + data[end_at_key] + '.';
        value = '<a data-tooltip="' + tip + '" class="tooltipped not-submitted">' + value + '</a>';
        break;

      case "not_yet_submitted":
        tip = user + ' has not yet made any submissions for ' + asmt + '. <br>';
        tip += 'The last date for submission by ' + user + ' is ' + data[end_at_key] + '.';
        value = '<a data-tooltip="' + tip + '" class="tooltipped not-yet-submitted">' + value + '</a>';
        break;
      }
    }
    return (value !== null) ? ((data[history_key] !== undefined) ? link_to(data[history_key], value) : value) : "&ndash;";
  }
};

function comparer(a, b) {
  var x = a[sort_column], y = b[sort_column];
  return (x == y ? 0 : (x > y ? 1 : -1));
}

function filter(item, args) {
  var filter = args.filter_string.toLowerCase();

  if (filter == "") {
    return true 
  } else if (item["email"].toLowerCase().indexOf(filter) != -1 ||
             item["first_name"].toLowerCase().indexOf(filter) != -1 ||
             item["last_name"].toLowerCase().indexOf(filter) != -1) {
    return true;
  } else {
    return false;
  }
}

function link_to(url, title) {
  return "<a href=" + url + ">" + title + "</a>";
}

(function($) {

  $.extend(true, window, {
    "Slick": {
      "AutoColumnSize": AutoColumnSize
    }
  });

  function AutoColumnSize(maxWidth) {

    var grid, $container, context,
        keyCodes = {
          'A': 65
        };

    function init(_grid) {
      grid = _grid;
      maxWidth = maxWidth || 300;

      $container = $(grid.getContainerNode());
      $container.on("dblclick.autosize", ".slick-resizable-handle", reSizeColumn);
      $container.keydown(handleControlKeys);

      context = document.createElement("canvas").getContext("2d");
    }

    function destroy() {
      $container.off();
    }

    function handleControlKeys(event) {
      if (event.ctrlKey && event.shiftKey && event.keyCode === keyCodes.A) {
        resizeAllColumns();
      }
    }

    function resizeAllColumns() {
      var elHeaders = $container.find(".slick-header-column");
      var allColumns = grid.getColumns();
      elHeaders.each(function(index, el) {
        var columnDef = $(el).data('column');
        var headerWidth = getElementWidth(el);
        var colIndex = grid.getColumnIndex(columnDef.id);
        var column = allColumns[colIndex];
        var autoSizeWidth = Math.max(headerWidth, getMaxColumnTextWidth(columnDef, colIndex)) + 1;
        autoSizeWidth = Math.min(maxWidth, autoSizeWidth);
        column.width = autoSizeWidth;
      });
      grid.setColumns(allColumns);
      grid.onColumnsResized.notify();
    }

    function reSizeColumn(e) {
      var headerEl = $(e.currentTarget).closest('.slick-header-column');
      var columnDef = headerEl.data('column');

      if (!columnDef || !columnDef.resizable) {
        return;
      }

      e.preventDefault();
      e.stopPropagation();

      var headerWidth = getElementWidth(headerEl[0]);
      var colIndex = grid.getColumnIndex(columnDef.id);
      var allColumns = grid.getColumns();
      var column = allColumns[colIndex];

      var autoSizeWidth = Math.max(headerWidth, getMaxColumnTextWidth(columnDef, colIndex)) + 1;

      if (autoSizeWidth !== column.width) {
        column.width = autoSizeWidth;
        grid.setColumns(allColumns);
        grid.onColumnsResized.notify();
      }
    }

    function getMaxColumnTextWidth(columnDef, colIndex) {
      var texts = [];
      var rowEl = createRow(columnDef);
      var data = grid.getData();
      if (Slick.Data && data instanceof Slick.Data.DataView) {
        data = data.getItems();
      }
      for (var i = 0; i < data.length; i++) {
        texts.push(data[i][columnDef.field]);
      }
      var template = getMaxTextTemplate(texts, columnDef, colIndex, data, rowEl);
      var width = getTemplateWidth(rowEl, template);
      deleteRow(rowEl);
      return width;
    }

    function getTemplateWidth(rowEl, template) {
      var cell = $(rowEl.find(".slick-cell"));
      cell.append(template);
      $(cell).find("*").css("position", "relative");
      return cell.outerWidth() + 1;
    }

    function getMaxTextTemplate(texts, columnDef, colIndex, data, rowEl) {
      var max = 0,
          maxTemplate = null;
      var formatFun = columnDef.formatter;
      $(texts).each(function(index, text) {
        var template;
        if (formatFun) {
          template = $("<span>" + formatFun(index, colIndex, text, columnDef, data[index]) + "</span>");
          text = template.text() || text;
        }
        var length = text ? getElementWidthUsingCanvas(rowEl, text) : 0;
        if (length > max) {
          max = length;
          maxTemplate = template || text;
        }
      });
      return maxTemplate;
    }

    function createRow(columnDef) {
      var rowEl = $('<div class="slick-row"><div class="slick-cell"></div></div>');
      rowEl.find(".slick-cell").css({
        "visibility": "hidden",
        "text-overflow": "initial",
        "white-space": "nowrap"
      });
      var gridCanvas = $container.find(".grid-canvas");
      $(gridCanvas).append(rowEl);
      return rowEl;
    }

    function deleteRow(rowEl) {
      $(rowEl).remove();
    }

    function getElementWidth(element) {
      var width, clone = element.cloneNode(true);
      clone.style.cssText = 'position: absolute; visibility: hidden;right: auto;text-overflow: initial;white-space: nowrap;';
      element.parentNode.insertBefore(clone, element);
      width = clone.offsetWidth;
      clone.parentNode.removeChild(clone);
      return width;
    }

    function getElementWidthUsingCanvas(element, text) {
      context.font = element.css("font-size") + " " + element.css("font-family");
      var metrics = context.measureText(text);
      return metrics.width;
    }

    return {
      init: init,
      destroy: destroy
    };
  }

  $.extend(true, window, {
    "Slick": {
      "Plugins": {
        "HeaderMenu": HeaderMenu
      }
    }
  });

  function HeaderMenu(options) {
    var _grid;
    var _self = this;
    var _handler = new Slick.EventHandler();
    var _defaults = {
      buttonCssClass: null,
      buttonImage: null
    };
    var $menu;
    var $activeHeaderColumn;


    function init(grid) {
      options = $.extend(true, {}, _defaults, options);
      _grid = grid;
      _handler
          .subscribe(_grid.onHeaderCellRendered, handleHeaderCellRendered)
          .subscribe(_grid.onBeforeHeaderCellDestroy, handleBeforeHeaderCellDestroy);

      // Force the grid to re-render the header now that the events are hooked up.
      _grid.setColumns(_grid.getColumns());

      // Hide the menu on outside click.
      $(document.body).bind("mousedown", handleBodyMouseDown);
    }


    function destroy() {
      _handler.unsubscribeAll();
      $(document.body).unbind("mousedown", handleBodyMouseDown);
    }


    function handleBodyMouseDown(e) {
      if ($menu && $menu[0] != e.target && !$.contains($menu[0], e.target)) {
        hideMenu();
      }
    }


    function hideMenu() {
      if ($menu) {
        $menu.remove();
        $menu = null;
        $activeHeaderColumn
            .removeClass("slick-header-column-active");
      }
    }

    function handleHeaderCellRendered(e, args) {
      var column = args.column;
      var menu = column.header && column.header.menu;

      if (menu) {
        var $el = $("<div></div>")
            .addClass("slick-header-menubutton")
            .data("column", column)
            .data("menu", menu);

        if (options.buttonCssClass) {
          $el.addClass(options.buttonCssClass);
        }

        if (options.buttonImage) {
          $el.css("background-image", "url(" + options.buttonImage + ")");
        }

        if (menu.tooltip) {
          $el.attr("title", menu.tooltip);
        }

        $el
            .bind("click", showMenu)
            .appendTo(args.node);
      }
    }


    function handleBeforeHeaderCellDestroy(e, args) {
      var column = args.column;

      if (column.header && column.header.menu) {
        $(args.node).find(".slick-header-menubutton").remove();
      }
    }


    function showMenu(e) {
      var $menuButton = $(this);
      var menu = $menuButton.data("menu");
      var columnDef = $menuButton.data("column");

      // Let the user modify the menu or cancel altogether,
      // or provide alternative menu implementation.
      if (_self.onBeforeMenuShow.notify({
        "grid": _grid,
        "column": columnDef,
        "menu": menu
      }, e, _self) == false) {
        return;
      }


      if (!$menu) {
        $menu = $("<div class='slick-header-menu'></div>")
            .appendTo(_grid.getContainerNode());
      }
      $menu.empty();


      // Construct the menu items.
      for (var i = 0; i < menu.items.length; i++) {
        var item = menu.items[i];

        var $li = $("<div class='slick-header-menuitem'></div>")
            .data("command", item.command || '')
            .data("column", columnDef)
            .data("item", item)
            .bind("click", handleMenuItemClick)
            .appendTo($menu);

        if (item.disabled) {
          $li.addClass("slick-header-menuitem-disabled");
        }

        if (item.tooltip) {
          $li.attr("title", item.tooltip);
        }

        if (item.iconCssClass) {
          var $icon = $("<div class='slick-header-menuicon'></div>")
              .appendTo($li);
          $icon.addClass(item.iconCssClass);
        }

        if (item.iconImage) {
          $icon.css("background-image", "url(" + item.iconImage + ")");
        }

        $("<span class='slick-header-menucontent'></span>")
            .text(item.title)
            .appendTo($li);
      }


      // Position the menu.
      $menu
          .offset({ top: $(this).offset().top + $(this).height(), left: $(this).offset().left });


      // Mark the header as active to keep the highlighting.
      $activeHeaderColumn = $menuButton.closest(".slick-header-column");
      $activeHeaderColumn
          .addClass("slick-header-column-active");

      // Stop propagation so that it doesn't register as a header click event.
      e.preventDefault();
      e.stopPropagation();
    }


    function handleMenuItemClick(e) {
      var command = $(this).data("command");
      var columnDef = $(this).data("column");
      var item = $(this).data("item");

      if (item.disabled) {
        return;
      }

      hideMenu();

      if (command != null && command != '') {
        _self.onCommand.notify({
          "grid": _grid,
          "column": columnDef,
          "command": command,
          "item": item
        }, e, _self);
      }

      // Stop propagation so that it doesn't register as a header click event.
      e.preventDefault();
      e.stopPropagation();
    }

    $.extend(this, {
      "init": init,
      "destroy": destroy,

      "onBeforeMenuShow": new Slick.Event(),
      "onCommand": new Slick.Event()
    });
  }
}(jQuery));



$(function () {
  // enumerator
  columns[0].formatter = function(row, cell, val, colDef, data) {
    return row + 1;
  };

  // Andrew column linkify
  if (options.linkify_andrew_ids) {
    columns[1].formatter = columns[columns.length - 1].formatter =
      function(row, cell, val, colDef, data) {
        return link_to(data["student_gradebook_link"], val);
      };

    columns[0].formatter =
      function(row, cell, val, colDef, data) {
        return link_to(data["student_gradebook_link"], row+1);
      };
  }

  // column header tooltips
  for (var i = 0; i < columns.length; i++) {
    if (columns[i].name == "Version") {
      columns[i].toolTip = columns[i-1].name + " " + columns[i].name;
    } else {
      columns[i].toolTip = columns[i].name;
    }
  }

  var dataView = new Slick.Data.DataView();
  grid = new Slick.Grid("#gradebook", dataView, columns, slickgrid_options);
  grid.registerPlugin( new Slick.AutoColumnSize());

  // new Slick.Controls.ColumnPicker(columns, grid, options);

  let hiddenColumns = localStorage.getItem("hiddenColumns") ? localStorage.getItem("hiddenColumns") : [];
  let hiddenNumberColumns = hiddenColumns.length === 0 ? [] : hiddenColumns.split(',').map(Number);
  let hiddenNumberSet = [... new Set(hiddenNumberColumns)];
  let visibleColumns = columns.filter((_, i) => !hiddenNumberSet.includes(i));


  grid.onSort.subscribe(function (e, args) {
    sort_column = args.sortCol.field;
    dataView.sort(comparer, args.sortAsc);
  });

  dataView.onRowCountChanged.subscribe(function (e, args) {
    grid.updateRowCount();
    grid.render();
  });

  dataView.onRowsChanged.subscribe(function (e, args) {
    grid.invalidateRows(args.rows);
    grid.render();
  });

  $("#filter").keyup(function (e) {
    // clear on Esc
    if (e.which == 27) { this.value = ""; }

    dataView.setFilterArgs({ filter_string: this.value });
    dataView.refresh();
  });

  // initialize the model after all the events have been hooked up
  dataView.beginUpdate();
  dataView.setItems(data);
  dataView.setFilter(filter);
  dataView.setFilterArgs({ filter_string: "" });
  dataView.endUpdate();

  // resize grid to fit window
  $(window).resize(function(e) {
    var before = $('#gradebook').offset().top;
    var after = 30;
    $("#gradebook").height($(window).height() - before - after);
    grid.resizeCanvas();
  });
  $(window).resize();

  const tooltipOpts = {
    position: 'top',
    delay: 100,
    html: true
  };
  grid.onMouseEnter.subscribe(function(e, args) {
    // Since Materialize's tooltip method was overwritten by jquery-ui
    M.Tooltip.init(document.querySelectorAll(".tooltipped"), tooltipOpts);
  });

  for (var i = 0; i < columns.length; i++) {
    columns[i].header = {
      menu: {
        items: [
          {
            title: "Hide Column",
            command: "hide",
            data: i
          },
          {
            title: "Unhide Columns",
            command: "unhide"
          },
          {
            title: "Synchronize Resize",
            command: "syncresize"
          },
          {
            title: "Force fit columns",
            command: "autoresize"
          }
        ]
      }
    };
  }

  var headerMenuPlugin = new Slick.Plugins.HeaderMenu({});

  headerMenuPlugin.onCommand.subscribe(function(e, args) {
    if (args.command === "hide") {
      hiddenColumns = localStorage.getItem("hiddenColumns") ? localStorage.getItem("hiddenColumns") : [];
      let hiddenNumberColumns = hiddenColumns.length === 0 ? [] : hiddenColumns.split(',').map(Number);
      hiddenNumberColumns.push(args.item.data);
      let hiddenNumberSet = [... new Set(hiddenNumberColumns)];
      visibleColumns = columns.filter((_, i) => !hiddenNumberSet.includes(i));
      localStorage.setItem("hiddenColumns", hiddenNumberSet.toString());
      grid.setColumns(visibleColumns);
    }
    else if (args.command === "unhide") {
      hiddenColumns = [];
      visibleColumns = columns;
      localStorage.clear();
      grid.setColumns(visibleColumns);
    }
    else if (args.command === "syncresize") {
      let syncresize = localStorage.getItem("syncresize")
      grid.setOptions({syncColumnCellResize: syncresize});
      localStorage.setItem("syncresize", !syncresize);
    }
    else if (args.command === "autoresize") {
      let autoresize = localStorage.getItem("autoresize")
      grid.setOptions({forceFitColumns: autoresize});
      if (autoresize) {
        grid.autosizeColumns();
      }
      localStorage.setItem("autoresize", !autoresize);
    }
  });

  grid.registerPlugin(headerMenuPlugin);
  console.log(visibleColumns);
  grid.setColumns(visibleColumns);
})
