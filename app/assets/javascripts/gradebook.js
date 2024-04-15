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
  var autoColumnResize = new Slick.Plugins.AutoColumnSize(300);
  grid.registerPlugin(autoColumnResize);

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
    else if (args.command === "autoresize") {
      let autoresize = localStorage.getItem("autoresize")
      if (autoresize) {
        grid.setOptions({forceFitColumns: !autoresize});
        grid.autosizeColumns();
      }
      localStorage.setItem("autoresize", autoresize);
    }
  });

  grid.registerPlugin(headerMenuPlugin);
  grid.setColumns(visibleColumns);
})
