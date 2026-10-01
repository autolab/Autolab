(function () {
  const types = {
    users: {
      heading: 'Users',
      inputName: 'user_ids[]',
      columns: [
        { key: 'name', label: 'Name' },
        { key: 'email', label: 'Email' },
        { key: 'role', label: 'Role' }
      ]
    },
    assessments: {
      heading: 'Assessments',
      inputName: 'assessment_ids[]',
      columns: [
        { key: 'name', label: 'Assessment' },
        { key: 'identifier', label: 'Identifier' }
      ]
    }
  };

  const render = function (container, type, items, idPrefix) {
    const definition = types[type];
    container.replaceChildren();

    const section = document.createElement('section');
    section.className = 'export-selection';

    const header = document.createElement('div');
    header.className = 'export-selection-header';
    const heading = document.createElement('h3');
    heading.textContent = definition.heading;
    const count = document.createElement('span');
    count.className = 'export-selection-count';
    header.appendChild(heading);
    header.appendChild(count);
    section.appendChild(header);

    if (items.length === 0) {
      const empty = document.createElement('p');
      empty.textContent = `This package has no ${type}.`;
      section.appendChild(empty);
      container.appendChild(section);
      return;
    }

    const controls = document.createElement('div');
    controls.className = 'export-selection-controls';
    const searchLabel = document.createElement('label');
    const search = document.createElement('input');
    search.type = 'search';
    search.id = `${idPrefix}_${type}_search`;
    search.className = 'export-search';
    search.placeholder = type === 'users' ? 'Name or email' : 'Name';
    search.autocomplete = 'off';
    searchLabel.className = 'export-search-label';
    searchLabel.htmlFor = search.id;
    searchLabel.textContent = `Search ${type}`;
    controls.appendChild(searchLabel);
    controls.appendChild(search);

    const selectVisible = document.createElement('button');
    selectVisible.type = 'button';
    selectVisible.className = 'btn-flat';
    selectVisible.textContent = 'Select visible';
    const unselectVisible = document.createElement('button');
    unselectVisible.type = 'button';
    unselectVisible.className = 'btn-flat';
    unselectVisible.textContent = 'Unselect visible';
    controls.appendChild(selectVisible);
    controls.appendChild(unselectVisible);
    section.appendChild(controls);

    const tableWrapper = document.createElement('div');
    tableWrapper.className = 'export-selection-table-wrapper';
    const table = document.createElement('table');
    table.className = 'prettyBorder export-selection-table';
    const headRow = table.createTHead().insertRow();
    const selectAllCell = document.createElement('th');
    selectAllCell.className = 'export-checkbox-column';
    const selectAllLabel = document.createElement('label');
    selectAllLabel.className = 'export-checkbox-label';
    const selectAll = document.createElement('input');
    selectAll.type = 'checkbox';
    selectAll.setAttribute('aria-label', `Select visible ${type}`);
    selectAllLabel.appendChild(selectAll);
    selectAllLabel.appendChild(document.createElement('span'));
    selectAllCell.appendChild(selectAllLabel);
    headRow.appendChild(selectAllCell);
    definition.columns.forEach((column) => {
      const cell = document.createElement('th');
      cell.textContent = column.label;
      headRow.appendChild(cell);
    });

    const body = table.createTBody();
    items.forEach((item, index) => {
      const row = body.insertRow();
      row.className = 'export-selection-row';
      const selectionCell = row.insertCell();
      selectionCell.className = 'export-checkbox-column';
      const label = document.createElement('label');
      label.className = 'export-checkbox-label';
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.className = 'export-selection-checkbox';
      checkbox.name = definition.inputName;
      checkbox.value = String(item.id);
      checkbox.checked = true;
      checkbox.id = `${idPrefix}_${type}_${index}`;
      checkbox.setAttribute('aria-label', `Include ${item.name || item.email || item.identifier}`);
      label.appendChild(checkbox);
      label.appendChild(document.createElement('span'));
      selectionCell.appendChild(label);

      definition.columns.forEach((column) => {
        const cell = row.insertCell();
        cell.textContent = item[column.key] || '';
      });
    });
    tableWrapper.appendChild(table);
    section.appendChild(tableWrapper);
    container.appendChild(section);

    const rows = Array.from(body.rows);
    const visibleRows = function () { return rows.filter((row) => !row.hidden); };
    const update = function () {
      const checkboxes = rows.map((row) => row.querySelector('input[type="checkbox"]'));
      const visible = visibleRows().map((row) => row.querySelector('input[type="checkbox"]'));
      const selected = checkboxes.filter((checkbox) => checkbox.checked).length;
      const visibleSelected = visible.filter((checkbox) => checkbox.checked).length;
      count.textContent = `${selected} of ${checkboxes.length} selected`;
      selectAll.checked = visible.length > 0 && visibleSelected === visible.length;
      selectAll.indeterminate = visibleSelected > 0 && visibleSelected < visible.length;
    };
    const setVisible = function (checked) {
      visibleRows().forEach((row) => {
        row.querySelector('input[type="checkbox"]').checked = checked;
      });
      update();
    };

    search.addEventListener('input', function () {
      const query = search.value.trim().toLowerCase();
      rows.forEach((row) => { row.hidden = !row.textContent.toLowerCase().includes(query); });
      update();
    });
    selectVisible.addEventListener('click', function () { setVisible(true); });
    unselectVisible.addEventListener('click', function () { setVisible(false); });
    selectAll.addEventListener('change', function () { setVisible(selectAll.checked); });
    rows.forEach((row) => {
      row.querySelector('input[type="checkbox"]').addEventListener('change', update);
    });
    update();
  };

  window.CourseTransferSelection = { render: render };

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-course-transfer-selector]').forEach((container) => {
      const data = JSON.parse(container.querySelector('script[type="application/json"]').textContent);
      render(container, container.dataset.courseTransferSelector, data, container.dataset.idPrefix);
    });
  });
}());
