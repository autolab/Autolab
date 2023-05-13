// Loads all Semantic javascripts
//= require semantic-ui

const github_endpoints = {
  get_repos: '/github_integration/get_repositories',
  get_branches: '/github_integration/get_branches',
  get_commits: '/github_integration/get_commits',
}

function update_repos() {
  $.getJSON(github_endpoints['get_repos'], function(data, status) {
    repos_html = "";
    data.forEach(repo => {
      repos_html += `<div class="item">${repo["repo_name"]}</div>`;
    });
    $("#repo-dropdown .menu").html(repos_html);
  });
}

function clear_branches() {
  $("#branch-dropdown input[name='branch']").addClass("noselection");
  $("#branch-dropdown .text").addClass("default");
  $("#branch-dropdown .text").text("Select branch");
  $("#branch-dropdown .menu").html("");
}

function clear_commits() {
  $("#commit-dropdown input[name='commit']").addClass("noselection");
  $("#commit-dropdown .text").addClass("default");
  $("#commit-dropdown .text").text("Select commit");
  $("#commit-dropdown .menu").html("");
}

function update_branches(repo) {
  clear_branches();
  clear_commits();
  $.getJSON(github_endpoints['get_branches'], {repository: repo}, function(data, status) {
    branches_html = "";
    data.forEach(branch => {
      branches_html += `<div class="item">${branch["name"]}</div>`;
    });
    $("#branch-dropdown .menu").html(branches_html);
  });
}

function update_commits(repo, branch) {
  clear_commits();
  $.getJSON(github_endpoints['get_commits'], {repository: repo, branch: branch}, function(data, status) {
    commits_html = "";
    data.forEach(commit => {
      commits_html += `<div data-value="${commit["sha"]}" class="item">${commit["sha"]} (${commit["msg"]})</div>`;
    });
    $("#commit-dropdown .menu").html(commits_html);
  });
}

$("a[data-tab=github]").click(function (e) {
  update_repos();
});

$("#repo-dropdown").change(function() {
  var repo_name = $("#repo-dropdown input[name='repo']").val();
  update_branches(repo_name);
});

$("#branch-dropdown").change(function() {
  var repo_name = $("#repo-dropdown input[name='repo']").val();
  var branch_name = $("#branch-dropdown input[name='branch']").val();
  update_commits(repo_name, branch_name);
});

// https://stackoverflow.com/questions/5524045/jquery-non-ajax-post
function submit(action, method, input) {
  'use strict';
  var form;
  form = $('<form />', {
      action: action,
      method: method,
      style: 'display: none;'
  });
  if (typeof input !== 'undefined' && input !== null) {
      $.each(input, function (name, value) {
          $('<input />', {
              type: 'hidden',
              name: name,
              value: value
          }).appendTo(form);
      });
  }
  form.appendTo('body').submit();
}

$(document).on("click", "input[type='submit']", function (e) {
  var tab = $(".submission-panel .ui.tab.active").attr('id');
  if (tab === "github_tab" && !$(this).is(":disabled")) {
    e.preventDefault();
    var repo_name = $("#repo-dropdown input[name='repo']").val();
    var branch_name = $("#branch-dropdown input[name='branch']").val();
    var commit_sha = $("#commit-dropdown input[name='commit']").val();
    var token = $("meta[name=csrf-token]").attr("content");
    var params = {
      repo: repo_name, branch: branch_name, commit: commit_sha, authenticity_token: token, github_submission: true
    };
    var assessment_nav = $(".sub-navigation").find(".item").last();
    var assessment_url = assessment_nav.find("a").attr("href");
    var url = assessment_url + "/handin"
    submit(url, 'post', params);
  }
});

$(document).ready(function () {
  $('.ui.dropdown input[type="hidden"]').val("");
  $('.ui.dropdown').dropdown({
    fullTextSearch: true,
  });
});
