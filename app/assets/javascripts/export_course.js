document.addEventListener('DOMContentLoaded', function () {
  const rowsFor = function (type) {
    return Array.from(document.querySelectorAll(`[data-export-row="${type}"]`));
  };

  const visibleRowsFor = function (type) {
    return rowsFor(type).filter((row) => row.style.display !== 'none');
  };

  const updateSelectionUi = function (type) {
    const visibleRows = visibleRowsFor(type);
    const checkboxes = rowsFor(type).map((row) => row.querySelector('.export-selection-checkbox'));
    const selectedCount = checkboxes.filter((checkbox) => checkbox.checked).length;
    const visibleSelectedCount = visibleRows
      .map((row) => row.querySelector('.export-selection-checkbox'))
      .filter((checkbox) => checkbox.checked).length;
    const selectAll = document.querySelector(`[data-select-all="${type}"]`);
    const count = document.querySelector(`[data-selection-count="${type}"]`);

    if (selectAll) {
      selectAll.checked = visibleRows.length > 0 && visibleSelectedCount === visibleRows.length;
      selectAll.indeterminate = visibleSelectedCount > 0 && visibleSelectedCount < visibleRows.length;
    }
    if (count) {
      count.textContent = `${selectedCount} of ${checkboxes.length} selected`;
    }
  };

  const setVisibleSelection = function (type, selected) {
    visibleRowsFor(type).forEach((row) => {
      row.querySelector('.export-selection-checkbox').checked = selected;
    });
    updateSelectionUi(type);
  };

  document.querySelectorAll('[data-export-search]').forEach((search) => {
    search.addEventListener('input', function () {
      const type = search.dataset.exportSearch;
      const query = search.value.trim().toLowerCase();

      rowsFor(type).forEach((row) => {
        row.style.display = row.textContent.toLowerCase().includes(query) ? 'table-row' : 'none';
      });
      updateSelectionUi(type);
    });
  });

  document.querySelectorAll('[data-select-visible]').forEach((button) => {
    button.addEventListener('click', () => setVisibleSelection(button.dataset.selectVisible, true));
  });

  document.querySelectorAll('[data-unselect-visible]').forEach((button) => {
    button.addEventListener('click', () => setVisibleSelection(button.dataset.unselectVisible, false));
  });

  document.querySelectorAll('[data-select-all]').forEach((checkbox) => {
    checkbox.addEventListener('change', () => setVisibleSelection(checkbox.dataset.selectAll, checkbox.checked));
  });

  document.querySelectorAll('.export-selection-checkbox').forEach((checkbox) => {
    checkbox.addEventListener('change', () => updateSelectionUi(checkbox.dataset.exportItem));
  });

  ['users', 'assessments'].forEach(updateSelectionUi);
});
