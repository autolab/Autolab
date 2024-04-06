(function ($) {
  function SlickColumnPicker(columns, grid, options) {
    var $menu;
    var columnCheckboxes;
    var visibleColumns = [];
    var hiddenColumns = [];

    var defaults = {
      fadeSpeed: 250
    };

    function init() {
      grid.onHeaderContextMenu.subscribe(handleHeaderContextMenu);
      options = $.extend({}, defaults, options);
      $menu = $("<span class='slick-columnpicker' style='display:none;position:absolute;z-index:20;' />").appendTo(document.body);

      grid.onHeaderContextMenu.subscribe (function (e, args) {
        $menu.empty();
        e.preventDefault();
        let item = args.column;
        $("<button />").text("Hide Column").appendTo($menu).on("click", function() {
          hiddenColumns.push(item);
        });

        $("body").one("click", function () {
          $("#contextMenu").hide();
        });

        $menu
            .css("top", e.pageY - 10)
            .css("left", e.pageX - 10)
            .fadeIn(options.fadeSpeed);
      })

      $menu.bind("mouseleave", function (e) {
        $(this).fadeOut(options.fadeSpeed);
      });

      $menu.bind("click", updateColumn);
    }

    function handleHeaderContextMenu(e, args) {
      e.preventDefault();
      $menu.empty();
      columnCheckboxes = [];

      var $li, $input, $span;
      $("<span />").text("Toggle on/off").appendTo($menu)
      for (var i = 0; i < columns.length; i++) {

        $li = $("<li />").appendTo($menu);

        $input = $("<input type='checkbox'/>").data("column-id", columns[i].id).attr("data-id", i);
        columnCheckboxes.push($input);
        if (grid.getColumnIndex(columns[i].id) != null) {
          $input.attr("checked", "checked");
        }
        $span = $("<span />").text(columns[i].name)

        $("<label />")
            .append($input)
            .append($span)
            .appendTo($li);
      }

      $("<hr/>").appendTo($menu);
      $li = $("<li />").appendTo($menu);
      $input = $("<input type='checkbox' />").data("option", "autoresize");
      $span = $("<span />").text("Force fit columns")
      $("<label />")
          .prepend($input)
          .append($span)
          .appendTo($li);
      if (grid.getOptions().forceFitColumns) {
        $input.attr("checked", "checked");
      }

      $li = $("<li />").appendTo($menu);
      $input = $("<input type='checkbox' />").data("option", "syncresize");
      $span = $("<span />").text("c")
      $("<label />")
          .prepend($input)
          .append($span)
          .appendTo($li);
      if (grid.getOptions().syncColumnCellResize) {
        $input.attr("checked", "checked");
      }

      $menu
          .css("top", e.pageY - 10)
          .css("left", e.pageX - 10)
          .fadeIn(options.fadeSpeed);
    }

    function updateColumn(e) {

      var assessment_versions = {}
      for (var i = 0; i < columns.length; i++) {
        var underscoreIndex = columns[i].name.lastIndexOf('_');
        var version = columns[i].name.substring(underscoreIndex + 1);
        if (version === "Version") {
          assessment_versions[i] = [i, i - 1];
          assessment_versions[i - 1] = [i, i - 1];
        }
      }

      if ($(e.target).data("option") == "autoresize") {
        if (e.target.checked) {
          grid.setOptions({forceFitColumns: true});
          grid.autosizeColumns();
        } else {
          grid.setOptions({forceFitColumns: false});
        }
        return;
      }

      if ($(e.target).data("option") == "syncresize") {
        if (e.target.checked) {
          grid.setOptions({syncColumnCellResize: true});
        } else {
          grid.setOptions({syncColumnCellResize: false});
        }
        return;
      }

      $("input").click(function (event) {
        var column_index = event.target.dataset.id
        if (column_index in assessment_versions) {
          var checked = event.target.checked
          columnCheckboxes[assessment_versions[column_index][0]].prop("checked", checked)
          columnCheckboxes[assessment_versions[column_index][1]].prop("checked", checked)
        }
      })


      if ($(e.target).is(":checkbox")) {
        $.each(columnCheckboxes, function (i, e) {
          if ($(this).is(":checked")) {
            visibleColumns.push(columns[i]);
          }
        });

        if (!visibleColumns.length) {
          $(e.target).attr("checked", "checked");
          return;
        }

        grid.setColumns(visibleColumns);
      }
    }

    init();
  }

  // Slick.Controls.ColumnPicker
  $.extend(true, window, {Slick: {Controls: {ColumnPicker: SlickColumnPicker}}});
})(jQuery);
