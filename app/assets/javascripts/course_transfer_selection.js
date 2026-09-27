(function () {
  const types = {
    users: {
      heading: 'Users', inputName: 'user_ids[]', placeholder: 'Name or email',
      columns: [
        { key: 'name', label: 'Name' },
        { key: 'email', label: 'Email' },
        { key: 'role', label: 'Role' }
      ]
    },
    assessments: {
      heading: 'Assessments', inputName: 'assessment_ids[]', placeholder: 'Name',
      columns: [
        { key: 'name', label: 'Assessment' },
        { key: 'identifier', label: 'Identifier' }
      ]
    }
  };

  const render = function (container, type, items, idPrefix) {
    const definition = types[type];
    const tableId = `${idPrefix}_${type}_table`;
    const searchId = `${idPrefix}_${type}_search`;
    const columnHeaders = definition.columns.map((column) => `<th>${column.label}</th>`).join('');

    container.innerHTML = `
      <section class="export-selection">
        <div class="export-selection-header">
          <h3>${definition.heading}</h3>
          <span class="export-selection-count"></span>
        </div>
        ${items.length === 0 ? `<p>This package has no ${type}.</p>` : `
          <div class="export-selection-controls">
            <label class="export-search-label" for="${searchId}">Search ${type}</label>
            <input class="export-search" id="${searchId}" type="search"
                   placeholder="${definition.placeholder}" autocomplete="off">
            <button class="btn-flat" type="button" data-select-visible>Select visible</button>
            <button class="btn-flat" type="button" data-unselect-visible>Unselect visible</button>
          </div>
          <div class="export-selection-table-wrapper">
            <table class="prettyBorder export-selection-table" id="${tableId}">
              <thead><tr><th class="export-checkbox-column"></th>${columnHeaders}</tr></thead>
            </table>
          </div>
          <div data-selected-inputs hidden></div>
        `}
      </section>`;
    if (items.length === 0) return;

    const find = function (selector) { return container.querySelector(selector); };
    const dataTable = new DataTable(find('table'), {
      data: items,
      columns: [{
        data: null, orderable: false, searchable: false, render: DataTable.render.select()
      }].concat(definition.columns.map((column) => ({
        data: column.key, defaultContent: '', render: DataTable.render.text()
      }))),
      info: false,
      layout: { topStart: null, topEnd: null, bottomStart: null, bottomEnd: null },
      ordering: false,
      paging: false,
      select: { headerCheckbox: 'select-page', selector: 'td:first-child', style: 'multi' }
    });

    const synchronizeSelection = function () {
      const selected = dataTable.rows({ selected: true }).data().toArray();
      find('[data-selected-inputs]').replaceChildren(...selected.map((item) => {
        const input = document.createElement('input');
        Object.assign(input, {
          type: 'hidden', name: definition.inputName, value: String(item.id)
        });
        return input;
      }));
      find('.export-selection-count').textContent =
        `${selected.length} of ${items.length} selected`;
    };

    find('.export-search').addEventListener('input', function (event) {
      dataTable.search(event.target.value).draw();
    });
    find('[data-select-visible]').addEventListener('click', function () {
      dataTable.rows({ search: 'applied' }).select();
    });
    find('[data-unselect-visible]').addEventListener('click', function () {
      dataTable.rows({ search: 'applied' }).deselect();
    });
    dataTable.on('select deselect', synchronizeSelection);
    dataTable.rows().select();
    synchronizeSelection();
  };

  window.CourseTransferSelection = { render: render };
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-course-transfer-selector]').forEach((container) => {
      const dataElement = container.querySelector('script[type="application/json"]');
      const data = JSON.parse(dataElement.textContent);
      render(container, container.dataset.courseTransferSelector, data, container.dataset.idPrefix);
    });
  });
}());
