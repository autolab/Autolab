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

    const heading = document.createElement('h3');
    heading.textContent = definition.heading;
    container.appendChild(heading);

    if (items.length === 0) {
      const empty = document.createElement('p');
      empty.textContent = `This package has no ${type}.`;
      container.appendChild(empty);
      return;
    }

    const table = document.createElement('table');
    table.className = 'prettyBorder export-selection-table';
    const headRow = table.createTHead().insertRow();
    ['Include'].concat(definition.columns.map((column) => column.label)).forEach((label) => {
      const cell = document.createElement('th');
      cell.textContent = label;
      headRow.appendChild(cell);
    });

    const body = table.createTBody();
    items.forEach((item, index) => {
      const row = body.insertRow();
      const selectionCell = row.insertCell();
      const label = document.createElement('label');
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
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
    container.appendChild(table);
  };

  window.CourseTransferSelection = { render: render };

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-course-transfer-selector]').forEach((container) => {
      const data = JSON.parse(container.querySelector('script[type="application/json"]').textContent);
      render(container, container.dataset.courseTransferSelector, data, container.dataset.idPrefix);
    });
  });
}());
