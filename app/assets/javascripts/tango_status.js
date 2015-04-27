// Extend jQuery to allow setting `disabled` bit of many elements.
jQuery.fn.extend({
    disable: function(state) {
        return this.each(function() {
            this.disabled = state;
        });
    }
});

// initialize dataset
$.getJSON('tango_data', function(data) {
  data = jQuery.map(data, function(h) {
    h['dates'] = jQuery.map(h['dates'], function(d) {
      return new Date(d + "UTC");
    });
    return h;
  });
  plotEventDrops(data);
  plotTimeSeries(data);
});

// Plot the Event Drop graph.
var plotEventDrops = function(data) {
  var minDates = jQuery.map(data, function(h) {
    return Math.min.apply(null, h['dates']);
  });
  var startTime = new Date(Math.min.apply(null, minDates));
  var color = d3.scale.category20();
  // create chart function
  var eventDropsChart = d3.chart.eventDrops()
    .start(startTime - 4000000)
    .end(Date.now() + 4000000)
    .eventLineColor(function(datum, index) {
      switch (index) {
        case 0:
          return "#99ccff"
        case 1:
          return "#FF7300"
        case 2:
          return "#FF0000"
        default:
          return "#000000"
      }
    })
    .eventHover(function(e) {
      var tstamp = d3.select(e).data()[0]; // timestamp of event
      for (var row = 0; row < data.length; row++) {
        if (e.parentNode.firstChild.innerHTML.indexOf(data[row]['name']) == 0) {
          break;
        }
      }
      if (row == data.length) {
        return;
      }
      for (var idx = 0; idx < data[row]['dates'].length; idx++) { // Index of event
        if (data[row]['dates'][idx] == tstamp) {
          break;
        }
      }
      if (idx == data[row]['dates']) {
        return;
      }
      // display the event details
      document.getElementById('job_time').innerHTML = tstamp;
      document.getElementById('job_name').innerHTML = data[row]['job_name'][idx];
      document.getElementById('vm_id').innerHTML = data[row]['vm_id'][idx];
      document.getElementById('vm_pool').innerHTML = data[row]['vm_pool'][idx];
      document.getElementById('job_duration').innerHTML = data[row]['duration'][idx];
      document.getElementById('job_id').innerHTML = data[row]['job_id'][idx];
      var status;
      switch (row) {
        case 0:
          status = data[row]['status'][idx];
          break;
        case 1:
          status = "Errored";
          break;
        case 2:
          status = "Failed";
          break;
      }

      document.getElementById('job_status').innerHTML = status;
    })
    .minScale(0.5)
    .maxScale(100)
    .width(1024)
    .margin({
      top: 60,
      left: 200,
      bottom: 0,
      right: 50
    });
  var element = d3.select('#tango_event_plot').datum(data);
  // draw the chart
  eventDropsChart(element);
  // set up window resize handler
  var chart = $("#tango_event_plot svg"),
    aspect = chart.width() / chart.height(),
    container = chart.parent();
  $(window).on("resize", function() {
    var targetWidth = container.width();
    chart.attr("width", targetWidth);
    chart.attr("height", Math.round(targetWidth / aspect));
  }).trigger("resize");
};

// Plot the time-series of job lengths.
var plotTimeSeries = function(data) {
  // Initialize Dataset
  var new_jobs = data[0];
  var eventarr = [];
  for (var i = 0; i < new_jobs.dates.length; i++) {
    var tmp = {};
    for (var k in new_jobs) {
      if (new_jobs[k].constructor === Array) {
        tmp[k] = new_jobs[k][i];
      }
    }
    eventarr.push(tmp);
  }
  /* Function called to update time-series. */
  var update_plot = function(pool) {
    $("#pool_selection button[name='vmpool'][value='" + pool + "']").prop('disabled', true);
    plot_diagram(pool);
  };
  /* Actual helper function to plot time-series for a pool (or global) */
  var plot_diagram = function(pool) {
    current_plot = pool;
    var title = "Job Runtime History for ";
    title += pool == '' ? "Global" : pool;
    MG.data_graphic({
      title: title,
      description: "This diagram shows a time-series of job lengths per VM pool. Drag a time range to zoom in; left click on the diagram to revert zooming. Hover on events to view details. <i>The y-axis is logarithmically scaled to show abnormalities.</i>",
      data: eventarr.filter(function(e) {
        return pool == '' || e.vm_pool == pool;
      }),
      full_width: true,
      height: 150,
      buffer: 5,
      target: '#tango_time_plot',
      x_accessor: 'dates',
      y_accessor: 'duration',
      y_scale_type: 'log',
      interpolate: 'linear',
      top: 28,
      buffer: 2,
      mouseover: function(d, i) {
        var prefix = d3.formatPrefix(d.value);
        var timestamp = d.dates.toString();
        timestamp = timestamp.substring(0, timestamp.lastIndexOf(':'));
        $('div#tango_time_plot svg .mg-active-datapoint')
          .html('Job ID: ' + d.job_id + ' | Submission Time: ' + timestamp + ' | Duration: ' + d.duration);
        document.getElementById('job_time').innerHTML = d.dates;
        document.getElementById('job_name').innerHTML = d.job_name;
        document.getElementById('vm_id').innerHTML = d.vm_id;
        document.getElementById('vm_pool').innerHTML = d.vm_pool;
        document.getElementById('job_duration').innerHTML = d.duration;
        document.getElementById('job_id').innerHTML = d.job_id;
        document.getElementById('job_status').innerHTML = d.status;
      }
    });
  };
  /* Initialize time-series diagram. */
  $(document).ready(function() {
    $("#pool_selection button[name='vmpool']").click(function() {
      $("button[name='vmpool']").disable(false);
      console.log(this);
      update_plot(jQuery(this).val());
    });
    update_plot('');
  });
};
