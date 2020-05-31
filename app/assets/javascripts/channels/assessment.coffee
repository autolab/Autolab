App.assessment = App.cable.subscriptions.create "AssessmentChannel",
  connected: ->
    # Called when the subscription is ready for use on the server

  disconnected: ->
    # Called when the subscription has been terminated by the server

  received: (data) ->
    # Called when there's incoming data on the websocket for this channel
    
    waiting_jobs = JSON.parse(data.jobs_queue.waiting_jobs);
    running_jobs = JSON.parse(data.jobs_queue.running_jobs);
    created_at = Date.parse(data.jobs_queue.created_at);
    
    waiting_jobs.sort();

    queueInfo = 
      onqueue: waiting_jobs.includes(curr_jobID)
      number: waiting_jobs.indexOf(curr_jobID) + 1
      grading: running_jobs.includes(curr_jobID)
      created_at: created_at/1000

    on_change(queueInfo)
    if(!queueInfo.onqueue && !queueInfo.grading)
        App.cable.subscriptions.remove(App.assessment)
    
  speak: ->
    @perform 'speak'
