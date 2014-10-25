$(function() {
  start = new Date();

  function bench(title) {
    console.log(title + ': ' + (new Date() - start));
  }

  var scoreViewTemplate = Handlebars.compile($('#score-template').html());

  function scoreViewHTML(scoreJSON) {
      var scoreHTML = scoreViewTemplate(scoreJSON);
      return scoreHTML;
  }

  function displayTotal(total) {
    var roundedTotal = parseFloat(total).toFixed(1);
    return '' + roundedTotal;
  }

  Handlebars.registerHelper('displayTotal', displayTotal);
  Handlebars.registerHelper('displayScoreView', function(problem, scores) {

    var score = _.find(scores, function(s) {
      return problem.id === s.problem_id;
    })
    var tdHTML = '<td class="score" data-problem-id="' + problem.id + '"';
    if (score) {
      tdHTML += 'data-score-id="' + score.id + '">';
      return tdHTML + scoreViewHTML(score);
    } else {
      tdHTML += 'data-score-id="0">';
      score = {
                score: null,
                id: 0,
                released: false
              };
      return tdHTML + scoreViewHTML(score);
    }
  });

  Handlebars.registerHelper('displayScore', function(score) {
    if (score === null) {
      return '&ndash;';
    }
    var roundedScore = parseFloat(Math.round(score * 100) / 100).toFixed(1);
    return '' + roundedScore;
  });

  Handlebars.registerHelper('displayLatePenalty', function(penalty) {
    var roundedPenalty = parseFloat(penalty).toFixed(1);
    return '' + roundedPenalty;
  });

  Handlebars.registerHelper('displayTweak', function(tweak) {
    if (tweak === null || tweak === undefined || tweak.value === 0) {
      return '&ndash;';
    }
    var end = '';
    switch (tweak.kind) {
      case "points":
        end = '';
        break;
      case "percent":
        end = '%';
        break;
      default:
        end = '';
        break;
    }
    return '+' + tweak.value + end;
  });

  User = Backbone.Model.extend();

  Grader = Backbone.Model.extend({
    urlRoot: '/' + course + '/user/',
  });

  Score = Backbone.Model.extend({
    defaults: {
      'grader': null,
      'score': null,
      'feedback': null,
      'released': false
    },
    initialize: function() {
      if (this.get('feedback') === null) {
        this.set('feedback', '');
      }
    },
    urlRoot: '/' + course + '/scores/',
  });

  ScoreList = Backbone.Collection.extend({
    model: Score
  });

  GraderList = Backbone.Collection.extend({
    model: Grader
  });

  var graders = new GraderList;

  var Submission = Backbone.Model.extend({
    urlRoot: '/' + course + '/submission/show/',
    initialize: function() {
      this.convertScores();
    },
    convertScores: function() {
      // Create Score models for each submission.
      var scoresArr = this.get('scores');
      var scores = {};
      _.each(scoresArr, function(s) {
        scores[s.problem_id] = new Score(s);
      });
      this.set('scores', scores);
    }
  });

  var SubmissionList = Backbone.Collection.extend({
    model: Submission
  });

  var Submissions = new SubmissionList;

  CurrentUser = new User(user);

  var ScoreView = Backbone.View.extend({
    events: {
      'click .view': 'edit',
      'keypress .edit': 'onKeypress',
      'keydown': 'onKeydown',
      'closeEdit': 'close'
    },
    initialize: function() {
      this.onSuccess = _.bind(this.onSuccess, this);
      this.pop = null;
    },

    popTemplate: _.template($('#score-popover-template').html()),

    render: function() {
      this.$el.html(scoreViewHTML(this.model.toJSON()));
      return this;
    },

    createOrShowPop: function() {
      if (this.pop === null) {
        // Lazily create popover.
        this.model.set({cid: this.model.cid});
        $('body').append(this.popTemplate(this.model.toJSON()));
        this.pop = $('#score-pop-' + this.model.get('cid'));
        // Listen to popover feedback keypresses.
        this.pop.find('.feedback').keypress(_.bind(this.onFeedbackKeypress, this));

        this.feedbackInput = this.pop.find('.feedback');
        this.releaseBox = this.pop.find('.released');
      } else {
        // A popover already exists so we just show it.
        this.pop.show();
      }
      this.pop.position({
        my: 'right center',
        at: 'left center',
        of: this.$el,
        offset: '10px 0'
      });
    },

    // Graders are lazily loaded here.
    getGrader: function() {
      var grader_id = this.model.get('grader_id');
      // Check if we've already loaded this grader.
      var grader = graders.find(function(grader) {
        return grader.get('id') === grader_id;
      });
      if (!grader && grader_id) {
        // Create the grader model.
        grader = new Grader({
          id: grader_id
        });
        var ths = this;
        // Ask the server to populate the model.
        grader.fetch().done(function() {
          ths.updateGrader(grader);
          graders.add(grader);
        });
      } else if (grader) {
        this.updateGrader(grader);
      }
    },

    // Editting a score.
    edit: function() {
      // Show popover.
      this.createOrShowPop();

      this.scoreInput = this.$el.find('.edit');

      // Lazily load the grader.
      this.getGrader();

      this.$el.addClass('editing');
      this.scoreInput.focus();

      // Tell SubmissionView we're editting.
      this.trigger('scoreEdit', this);
    },

    // Populate the grader field in score's popover.
    updateGrader: function(grader) {
      if (grader) {
        this.pop.find('#grader').html(grader.get('first_name') + ' ' +
                               grader.get('last_name') + ' (' +
                               grader.get('andrewID') + ')');
      } else {
        this.pop.find('#grader').html('None');
      }
    },

    // Close out of the ScoreView
    close: function() {
      // Hide popoever.
      this.pop.hide();
      // Grab the fields.
      var newScore = parseFloat(this.scoreInput.val());
      var newFeedback = this.feedbackInput.val();
      var newReleased = this.releaseBox.is(':checked');
      var oldScore = this.model.get('score');

      if (isNaN(newScore)) {
        this.scoreInput.val(oldScore);
        newScore = oldScore;
      }
      // Only update if things have changed.
      if (oldScore !== newScore ||
          this.model.get('feedback') !== newFeedback ||
          this.model.get('released') !== newReleased) {
          this.model.save({
                            score: newScore,
                            feedback: newFeedback,
                            released: newReleased,
                            grader_id: CurrentUser.get('id')
                          },
                          {
                            success: this.onSuccess,
                            error: this.onError
                          });
      }
      this.$el.removeClass('editing');
      // Tell SubmissionView we closed the score.
      this.trigger('scoreClose', this);
    },

    onKeypress: function(e) {
      switch (e.keyCode) {
        // Enter
        case 13:
          e.preventDefault();
          this.trigger('scoreMovement', 'down');
          break;
        // Back tick
        case 96:
          e.preventDefault();
          this.feedbackInput.focus();
          break;
        // l
        case 108:
          e.preventDefault();
          this.trigger('scoreMovement', 'right');
          break;
        // h
        case 104:
          e.preventDefault();
          this.trigger('scoreMovement', 'left');
          break;
        // j
        case 106:
          e.preventDefault();
          this.trigger('scoreMovement', 'down');
          break;
        // k
        case 107:
          e.preventDefault();
          this.trigger('scoreMovement', 'up');
          break;
      }
    },

    onFeedbackKeypress: function(e) {
      // Back tick
      if (e.keyCode == 96) {
        e.preventDefault();
        this.scoreInput.focus();
      }
    },

    onKeydown: function(e) {
      switch (e.keyCode) {
        // Tab
        case 9:
          e.preventDefault();
          if (e.shiftKey) {
            this.trigger('scoreMovement', 'backtab');
          } else {
            this.trigger('scoreMovement', 'tab');
          }
          break;
        // Right arrow
        case 39:
          e.preventDefault();
          this.trigger('scoreMovement', 'right');
          break;
        // Left arrow
        case 37:
          e.preventDefault();
          this.trigger('scoreMovement', 'left');
          break;
        // Down arrow
        case 40:
          e.preventDefault();
          this.trigger('scoreMovement', 'down');
          break;
        // Up arrow
        case 38:
          e.preventDefault();
          this.trigger('scoreMovement', 'up');
          break;
        }
    },

    // Score update success.
    onSuccess: function(model, response) {
      this.render();
      this.$el.effect('highlight', {color: 'lightgreen'}, 800);
      this.trigger('scoreChange');
    },

    // Score update failure.
    onError: function(model, response) {
      this.$el.effect('highlight', {color: 'lightred'}, 800);
    }
  });

  var SubmissionView = Backbone.View.extend({
    tagName: 'tr',
    className: 'submission',
    events: {
      'click .andrewID' : 'showPopover',
      'click .score' : 'openScore'
    },

    initialize: function() {
      this.pop = null;
      this.scoreViews = {};
    },

    popTemplate: _.template($('#submission-popover-template').html()),

    // Lazily create a score and open it.
    openScore: function(e) {
      var $td = $(e.target).closest('td');
      var problemId = $td.data('problem-id');
      // Create the score view if we haven't already.
      if (!this.scoreViews[problemId]) {
        var scoreView = this.createScore(problemId);
        scoreView.edit();
      }
    },

    createScore: function(problemId) {
      var score = this.model.get('scores')[problemId];
      var scoreView;
      if (score) {
        scoreView = new ScoreView({
          el: this.$('td[data-problem-id=\'' + problemId + '\']'),
          model: score
        });
      } else {
        var subId = this.$el.data('submission-id');
        var score = new Score({ submission_id: subId,
                                problem_id: problemId });
        scoreView = new ScoreView( {
          el: this.$('td[data-problem-id=\'' + problemId + '\']'),
          model: score
        });
      }
      // Listen to score view's events.
      scoreView.bind('scoreEdit', this.onScoreEdit, this);
      scoreView.bind('scoreChange', this.updateTotal, this);
      scoreView.bind('scoreClose', this.onScoreClose, this);
      scoreView.bind('scoreMovement', this.onScoreMovement, this);
      this.scoreViews[problemId] = scoreView;
      return scoreView;
    },

    getOrCreateScore: function(problemId) {
      if (!this.scoreViews[problemId]) {
        return this.createScore(problemId);
      } else {
        return this.scoreViews[problemId];
      }
    },

    // Lazily create and show submission popover.
    showPopover: function() {
      if (this.pop === null) {
        $('body').append(this.popTemplate(this.model.toJSON()));
        this.pop = $('#sub-pop-' + this.model.get('id'));
      }
      this.pop.show();
      this.pop.position({
        my: 'right center',
        at: 'left center',
        of: this.$('.id'),
        offset: '10px 0'
      });
      this.trigger('showPopover', this);
    },

    // Listen to clicks, and close popovers if necessary.
    onClick: function(e) {
      var targetClass = e.target.className;
      if (this.pop !== null && $(e.target).closest('div')[0] !== this.pop[0] &&
          $(e.target).closest('td')[0] !== this.$('.id')[0]) {
        this.pop.hide();
      }
      if (this.currScoreView &&
          $(e.target).closest('div')[0] !== this.currScoreView.pop[0] &&
          $(e.target).closest('td')[0] !== this.currScoreView.$el[0]) {
        this.currScoreView.close();
      }
    },

    // Listen to score view edit event.
    onScoreEdit: function(scoreView) {
      if (this.currScoreView) {
        this.currScoreView.close();
      }
      this.currScoreView = scoreView;
      this.trigger('showPopover', this);
    },

    // Listen to score view close event.
    onScoreClose: function() {
      this.currScoreView = null;
    },

    getCurrScoreViewProblemId: function() {
      return this.currScoreView.model.get('problem_id');
    },

    getLastProblemId: function() {
      return this.$el.find('.score').last().data('problem-id');
    },

    getFirstProblemId: function() {
      return this.$el.find('.score').first().data('problem-id');
    },

    onScoreMovement: function(type) {
      if (!this.currScoreView) {
        return;
      }
      if (type === 'tab' && !this.goRight()) {
        this.currScoreView.close();
        this.trigger('openScore', {'sub': this.getBelowIndex(),
                                   'score': this.getFirstProblemId()});
      }
      else if (type === 'backtab' && !this.goLeft()) {
        this.currScoreView.close();
        this.trigger('openScore', {'sub': this.getAboveIndex(),
                                   'score': this.getLastProblemId()});
      }
      else if (type === 'up' && !isNaN(this.getAboveIndex())) {
        this.trigger('openScore', {'sub': this.getAboveIndex(),
                                   'score': this.getCurrScoreViewProblemId()});
        this.currScoreView.close();
      }
      else if (type === 'down' && !isNaN(this.getBelowIndex())) {
        this.trigger('openScore', {'sub': this.getBelowIndex(),
                                   'score': this.getCurrScoreViewProblemId()});
        this.currScoreView.close();
      }
      else if (type === 'right') {
        this.goRight();
      }
      else if (type === 'left') {
        this.goLeft();
      }
    },

    // Move to scoreView to the right.
    goRight: function() {
      if (this.currScoreView) {
        var $next = this.currScoreView.$el.next('.score');
        return this.go($next);
      }
      return false;
    },

    // Move to the scoreView to the left.
    goLeft: function() {
      if (this.currScoreView) {
        var $prev = this.currScoreView.$el.prev('.score');
        return this.go($prev);
      }
      return false;
    },

    go: function($td) {
      if ($td.size() === 0) {
        return false;
      }
      var problemId = $td.data('problem-id');
      var scoreView = this.getOrCreateScore(problemId);
      scoreView.edit();
      return true;
    },

    getAboveIndex: function() {
      return parseInt(this.$el.prev('.submission').data('submission-id'));
    },

    getBelowIndex: function() {
      return parseInt(this.$el.next('.submission').data('submission-id'));
    },

    updateTotal: function() {
      var ths = this;
      this.model.fetch().always(function() {
        ths.model.convertScores();
        $('.total', ths.el).html(displayTotal(ths.model.get('total')).string);
      });
    }
  });

  var GradesheetView = Backbone.View.extend({
    el: $('body'),
    events: {
      'click' : 'onClick'
    },

    initialize: function() {
      this.gradesTable = $('table#grades');
      this.render();
      bench('RENDERED');
      this.populateSubmissions();
    },

    template: Handlebars.compile($('#submission-boot-template').html()),

    render: function() {
      var gradesheetHTML = this.template(submissions);
      this.gradesTable.append(gradesheetHTML);
    },

    // Create the submission views.
    populateSubmissions: function() {
      Submissions.reset(submissions);
      this.submissionViews = Submissions.map(function(item) {
        var submissionView = new SubmissionView({
          model: item,
          el: $('#submission-' + item.id)
        });
        submissionView.bind('showPopover', this.onShowPopover, this);
        submissionView.bind('openScore', this.onOpenScore, this);
        return submissionView;
      }, this);
    },

    onClick: function(e) {
      if (this.currSubmissionView) {
        this.currSubmissionView.onClick(e);
      }
      if (this.oldSubmissionView) {
        this.oldSubmissionView.onClick(e);
      }
    },

    onShowPopover: function(submissionView) {
      if (!this.currSubmissionView ||
          this.currSubmissionView !== submissionView) {
        this.oldSubmissionView = this.currSubmissionView;
        this.currSubmissionView = submissionView;
      }
    },

    onOpenScore: function(indices) {
      var subIndex = indices.sub;
      var problemId = indices.score;
      if (!isNaN(subIndex) && !isNaN(problemId)) {
        var submissionView = _.find(this.submissionViews, function(s) {
          return s.model.get('id') === subIndex;
        })
        submissionView.getOrCreateScore(problemId).edit();
      }
    },
  });
  var gradesheetView = new GradesheetView();

  start = new Date();

  var num_cols = jQuery("table#grades > thead > tr:first > th").length

  numeric_columns = []
  for (var i = first_problem_column; i < num_cols; i++)
      numeric_columns.push(i);

  non_searchable_columns = []
  for (var i = first_non_searchable_column; i < num_cols; i++)
    non_searchable_columns.push(i);

  // fast numeric-html sorts (but --'s aren't sorted correctly)
  jQuery.extend(jQuery.fn.dataTableExt.oSort, {
    "num-html-pre": function (a) {
      return parseFloat(String(a).replace(/<[\s\S]*?>/g, ""));
    },

    "num-html-asc": function ( a, b ) {
      a_nan = isNaN(a);
      b_nan = isNaN(b);
      if (a_nan) {
        if (b_nan) { return 0; } else { return -1; }
      } else {
        if (b_nan) { return 1; } else {
          return ((a < b) ? -1 : ((a > b) ? 1 : 0));
        }
      }
    },

    "num-html-desc": function ( a, b ) {
      a_nan = isNaN(a);
      b_nan = isNaN(b);
      if (a_nan) {
        if (b_nan) { return 0; } else { return 1; }
      } else {
        if (b_nan) { return -1; } else {
          return ((a > b) ? -1 : ((a < b) ? 1 : 0));
        }
      }
    }
  } );

  // main score table
  var oTable = jQuery("#grades").dataTable({
      'sDom' : '<"tools"f>t', // '<"tools"fC>t', for individual problem column hide/show
      'bPaginate': false,
      'bInfo': false,
      'oLanguage': { "sSearch": "" },
      'iTabIndex': -1,
      'aoColumnDefs': [
        { "bSortable": false, "aTargets": [ 0 ] },
        { "bSearchable": false, "aTargets": non_searchable_columns },
        { "sType": "html", "aTargets": [ andrewID_col ] },
        { "sType": "num-html", "aTargets": numeric_columns },
      ],
      "fnDrawCallback": function(oSettings) {
        var that = this;
        // Need to redo the counters if filtered or sorted
        if (oSettings.bSorted || oSettings.bFiltered) {
          asap(function() {
            that.$('td:first-child', { "filter": "applied" }).each(function(i) {
                that.fnUpdate(i + 1, this.parentNode, 0, false, false);
            });
          });
        }
      },
      // "aaSorting": [[ andrewID_col, 'asc' ]] -- this is slowww
  });

  console.log("datatables took: " + (new Date() - start));

  // placeholder text in Search field
  jQuery("#grades_filter input").attr("placeholder", "Search");

  /* Run f in the next runloop
   *
   * @param f Function to be executed
   */
  function asap(f) {
      setTimeout(f, 0);
  }

  jQuery("#grades_filter input").keydown(function(event){
          if (event.keyCode === 13) { // return
              asap(function() { jQuery(focusser).focus(); });
          } else if (event.keyCode === 27) { // esc
              event.preventDefault();
              jQuery(this).val("");
          }
  });

  jQuery('#grades_filter input').focus()
  console.log(new Date() - start)
});
