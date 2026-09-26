document.addEventListener('DOMContentLoaded', function () {
  const form = document.getElementById('course_import_form');
  if (!form) return;

  const fileInput = form.querySelector('input[type="file"]');
  const previewButton = form.querySelector('[data-import-preview]');
  const status = form.querySelector('[data-import-status]');
  const options = form.querySelector('[data-import-options]');
  const identifierField = form.querySelector('[data-course-identifier-field]');
  const identifier = form.querySelector('[name="course_identifier"]');
  const instructor = form.querySelector('[name="instructor_email"]');
  const selectionSubmitted = form.querySelector('[name="selection_submitted"]');
  const newDescription = form.querySelector('[data-new-import-description]');
  const legacyDescription = form.querySelector('[data-legacy-import-description]');
  const users = form.querySelector('[data-import-users]');
  const assessments = form.querySelector('[data-import-assessments]');
  const submit = form.querySelector('[data-import-submit]');
  const decoder = new TextDecoder('utf-8');

  const headerText = function (header, start, length) {
    return decoder.decode(header.slice(start, start + length)).replace(/\0.*$/, '').trim();
  };

  const inspectTar = async function (file) {
    const wanted = new Set(['manifest.yml', 'preview.json']);
    const found = {};
    let offset = 0;
    let entries = 0;

    while (offset + 512 <= file.size && wanted.size > 0) {
      const header = new Uint8Array(await file.slice(offset, offset + 512).arrayBuffer());
      if (header.every((byte) => byte === 0)) break;

      entries += 1;
      if (entries > 10000) throw new Error('The archive contains too many entries to preview.');

      const name = headerText(header, 0, 100);
      const prefix = headerText(header, 345, 155);
      const path = prefix ? `${prefix}/${name}` : name;
      const sizeText = headerText(header, 124, 12);
      const size = sizeText ? parseInt(sizeText, 8) : 0;
      if (!Number.isFinite(size) || size < 0) throw new Error('The archive has an invalid entry.');

      const dataOffset = offset + 512;
      const nextOffset = dataOffset + Math.ceil(size / 512) * 512;
      if (nextOffset > file.size) throw new Error('The archive is truncated.');

      if (wanted.has(path)) {
        found[path] = await file.slice(dataOffset, dataOffset + size).text();
        wanted.delete(path);
      }
      offset = nextOffset;
    }

    if (!found['manifest.yml']) return { legacy: true };
    if (!found['preview.json']) {
      throw new Error('This package has no browser preview. Export it again with this Autolab version.');
    }

    const preview = JSON.parse(found['preview.json']);
    if (!Array.isArray(preview.users) || !Array.isArray(preview.assessments)) {
      throw new Error('The package preview is invalid.');
    }
    return { legacy: false, preview: preview };
  };

  const renderSelection = function (container, type, items, columns) {
    container.replaceChildren();
    const heading = document.createElement('h3');
    heading.textContent = type === 'users' ? 'Users' : 'Assessments';
    container.appendChild(heading);

    if (items.length === 0) {
      const empty = document.createElement('p');
      empty.textContent = `This package has no ${type}.`;
      container.appendChild(empty);
      return;
    }

    const table = document.createElement('table');
    table.className = 'prettyBorder export-selection-table';
    const head = document.createElement('thead');
    const headRow = document.createElement('tr');
    ['Include'].concat(columns.map((column) => column.label)).forEach((label) => {
      const cell = document.createElement('th');
      cell.textContent = label;
      headRow.appendChild(cell);
    });
    head.appendChild(headRow);
    table.appendChild(head);

    const body = document.createElement('tbody');
    items.forEach((item, index) => {
      const row = document.createElement('tr');
      const selectionCell = document.createElement('td');
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.name = `${type === 'users' ? 'user' : 'assessment'}_ids[]`;
      checkbox.value = String(item.id);
      checkbox.checked = true;
      checkbox.id = `import_${type}_${index}`;
      checkbox.setAttribute('aria-label', `Include ${item.name || item.email || item.identifier}`);
      selectionCell.appendChild(checkbox);
      row.appendChild(selectionCell);

      columns.forEach((column) => {
        const cell = document.createElement('td');
        cell.textContent = item[column.key] || '';
        row.appendChild(cell);
      });
      body.appendChild(row);
    });
    table.appendChild(body);
    container.appendChild(table);
  };

  const resetPreview = function () {
    options.hidden = true;
    users.replaceChildren();
    assessments.replaceChildren();
    instructor.disabled = true;
    identifier.disabled = true;
    selectionSubmitted.disabled = true;
    previewButton.hidden = false;
    submit.value = 'Import Course';
    status.textContent = '';
  };

  fileInput.addEventListener('change', resetPreview);
  previewButton.addEventListener('click', async function () {
    const file = fileInput.files[0];
    if (!file) {
      status.textContent = 'Choose a course tarball first.';
      return;
    }

    previewButton.disabled = true;
    status.textContent = 'Inspecting package locally…';
    try {
      const result = await inspectTar(file);
      const legacy = result.legacy;
      form.action = legacy ? form.dataset.legacyImportUrl : form.dataset.newImportUrl;
      newDescription.hidden = legacy;
      legacyDescription.hidden = !legacy;
      identifierField.hidden = legacy;
      identifier.disabled = legacy;
      instructor.disabled = false;
      selectionSubmitted.disabled = legacy;

      if (legacy) {
        users.replaceChildren();
        assessments.replaceChildren();
        submit.value = 'Create Course';
        status.textContent = `${file.name} is a legacy course package.`;
      } else {
        renderSelection(users, 'users', result.preview.users, [
          { key: 'name', label: 'Name' },
          { key: 'email', label: 'Email' },
          { key: 'role', label: 'Role' }
        ]);
        renderSelection(assessments, 'assessments', result.preview.assessments, [
          { key: 'name', label: 'Assessment' },
          { key: 'identifier', label: 'Identifier' }
        ]);
        submit.value = 'Import Course';
        status.textContent = `${file.name} is ready to import (format ${result.preview.version}).`;
      }

      options.hidden = false;
      previewButton.hidden = true;
    } catch (error) {
      resetPreview();
      status.textContent = error instanceof Error ? error.message : 'Unable to preview this package.';
    } finally {
      previewButton.disabled = false;
    }
  });
});
