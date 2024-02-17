function drawDiffViewer() {
  const $diffViewer = $('#diff-viewer');
  const $diffViewerContents = $('#diff-viewer-contents');

  if ($diffViewer.length === 0) {
    return;
  }

  const diffString = $diffViewerContents.text();
  const configuration = {
    drawFileList: false,
    fileListToggle: false,
    fileListStartVisible: false,
    fileContentToggle: false,
    matching: 'lines',
    outputFormat: 'side-by-side',
    synchronisedScroll: true,
    highlight: true,
    renderNothingWhenEmpty: false,
  };
  const diff2htmlUi = new Diff2HtmlUI($diffViewer.get(0), diffString, configuration);
  diff2htmlUi.draw();
  diff2htmlUi.highlightCode();
}
