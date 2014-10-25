$(function() {
  _.templateSettings = {
      interpolate: /\{\{\=(.+?)\}\}/g,
     evaluate: /\{\{(.+?)\}\}/g
  };
});
