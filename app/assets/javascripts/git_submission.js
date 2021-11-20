// Loads all Semantic javascripts
//= require semantic-ui

const github_endpoints = {
  get_repos: '/github_integration/get_repositories',
	get_branches: '/github_integration/get_branches',
}

function update_repos() {
	$.getJSON(github_endpoints['get_repos'], function(data, status){
    repos_html = "";
    data.forEach(repo => {
      repos_html += `<div class="item">${repo["repo_name"]}</div>`;
    });
    $("#repo-dropdown .menu").html(repos_html);
  });
}

function update_branches(repo) {
  $("#branch-dropdown input[name='branch']").addClass("noselection");
  $("#branch-dropdown .text").addClass("default");
  $("#branch-dropdown .text").text("Select branch");
	$.getJSON(github_endpoints['get_branches'], {repository: repo}, function(data, status){
    branches_html = "";
    data.forEach(branch => {
      branches_html += `<div class="item">${branch["name"]}</div>`;
    });
    $("#branch-dropdown .menu").html(branches_html);
  });
}

$("a[data-tab=github]").click(function (e) {
  update_repos();
});

$("#repo-dropdown").change(function() {
  var repo_name = $("#repo-dropdown input[name='repo']").val();
  update_branches(repo_name);
});

$(document).on("click", "input[type='submit']", function (e) {
  var tab = $(".submission-panel .ui.tab.active").attr('id');
  if (tab === "github_tab" && !$(this).is(":disabled")) {
    e.preventDefault();
    var repo_name = $("#repo-dropdown input[name='repo']").val();
    var params = {repo: repo_name};
    var assessment_nav = $(".sub-navigation").find(".item").last();
    var assessment_url = assessment_nav.find("a").attr("href");
    var url = assessment_url + "/handin"
    $.ajax({
      type: 'POST',
      url: url,
      data: params, 
      success: function(data){
        window.location.replace(assessment_url + "/history");
      },
    });
  }
});

$(document).ready(function () {
  $('.ui.dropdown').dropdown({
    fullTextSearch: true,
  });
});
