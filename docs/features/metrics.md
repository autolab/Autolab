# Metrics

Traditional approaches of identifying students who are struggling with class is reactive; course staff wait for students to come to them to provide help, which can often be too late.

The metrics feature seeks to be a proactive approach by actively identifying students who might be struggling in class through tracking of metrics that signify possible risks. Identifying students in need of attention early in the course would provide a better chance of getting them back on track in the course.


## Usage Flow

We envision the feature to be used by the instructors in this order. They would:

1. Set up their course and assignments as per usual
1. Set up [Student Metrics](#student-metrics) at the start of the course
1. Be notified of pending students in need of attention in their [Watchlist](#watchlist) on the course page
1. Visit the [Watchlist](#watchlist), contact students if necessary, using it as a work list at the same time
1. Refine the [Student Metrics](#student-metrics) as the course progresses

## Student Metrics

![Student Metrics](/images/student_metrics.png)

From our interviews with instructors, we understand that different courses have different measures of whether a student is in need of attention. As such, a set of conditions together will define the course's student metrics. We intend to add more conditions to the metrics in the future. Feel free to suggest them via our <a href="https://github.com/autolab/Autolab/issues" target="_blank">GitHub Issues</a> page.

### Student Metrics Condition Rationale

The conditions are designed to capture different characteristics of a possible student in need of attention. In the sections that follow we attempt to explain the rationale behind each condition to aid with selecting the conditions.

#### Students who have used *number* grace days by *date*.

For courses that provides grace days, students who use many grace days early in the course tend to have issues managing the workload and/or their time. A good rule of thumb is that a student should not have used _**all**_ their grace days before the middle of the course.

#### Students whose grades have dropped by *number* percent within *number* consecutive assignments within a category

Identify students who have been slipping in their grades. Below are the underlying properties

- windowed based on the *number* consecutive 
- decrease must be consecutive
- skips over no-submissions

For example, given 4 assignments and we are looking for 20 percent grade drop over 3 consecutive assignments  

| Assignment | 1  | 2  | 3         | 4  | Grade Dropping?                                       |
|------------|----|----|-----------|----|-------------------------------------------------------|
| Student A  | 80 | 80 | 80        | 80 | No. Constant score                                    |
| Student B1 | 80 | 70 | 60        | 80 | Yes. Slipping from assignment 1,2,3                   |
| Student B2 | 80 | 80 | 70        | 60 | Yes. Slipping from assignment 2,3,4                   |
| Student C  | 80 | 90 | 60        | 70 | No. Although there was a drop, it was not 3 consecutive |
| Student D  | 90 | 80 | no submit | 80 | No. It skips over no submission                       |

#### Students who did not submit *number* assignments

Identify students who have not been submitting assignments. We made this a flexible number because we expect some courses to have ability to drop some assignments

#### Students with *number* submitted assignments below a percentage of *number*

Identify weaker students. We expect this condition to be useful earlier in the course, as it looks at all submitted assignments. It does not consider students who have not submitted an assignment.


## Watchlist

![Watchlist](/images/watchlist.png)

Once instructors have set up student metrics for their course, students that are identified as in need of attention based on these metrics will appear in the watchlist.

### Watchlist Instance

![Watchlist Instance](/images/watchlist_instance.png)

Every row in the watchlist represents a particular instance of a student who meets one or more of the metrics conditions. A single student can appear in multiple watchlist instances if they are identified for new metrics conditions on separate occasions of loading the watchlist. 

For example, let's look at Jane Doe in the image above. Upon loading the watchlist, Jane appears in a watchlist instance for using `3 grace days` before the instructor-specified date and for having `2 low scores` below the instructor-specified threshold. If Jane later receives another score below the threshold, a new instance will appear for Jane when the instructor reloads the watchlist. Jane now appears twice in the watchlist, once in an instance with `3 grace days` and `2 low scores`, and once in an instance with `3 grace days` and `3 low scores`.

#### Actions

The instructor can act on a watchlist instance by either contacting the student or resolving the student. Clicking the `contact` button on the watchlist instance directs the instructor to a mailto link and moves the instance into the `contacted` tab. Clicking the `resolve` button moves the instance into the `resolved` tab. The `contacted` and `resolved` tabs are discussed in the next section. To perform a "resolve" or "contact" in bulk, an instructor can click on multiple checkboxes and use the buttons located above the watchlist, or the instructor can select all by using the checkbox located above the watchlist.

An instructor can also hover over the condition tags to view the specific submissions and/or scores that led to the student being identified.

### Tabs

There are four categories that watchlist instances can fall into: pending, contacted, resolved, and archived.

#### Pending

The `pending` tab contains identified students who have not yet been contacted or resolved. The number of `pending` instances will appear in a notification badge on the main course page, as shown below. 

![Metrics Notification](/images/metrics_notification.png)

#### Contacted

The `contacted` tab contains all instances for which the instructor has contacted the student. Note: this does *not* mean that the student has been contacted for *all* associated watchlist instances.

#### Resolved

The `resolved` tab contains all instances that the instructor has marked as resolved. Note: this does *not* mean that the student has been marked as resolved for *all* associated watchlist instances.

#### Archived

When an instructor adjusts the student metrics for a course, all instances that were in `contacted` or `resolved` for the outdated student metrics are placed into `archived`. All `pending` instances for the outdated student metrics are dropped. As such, all instances in `pending`, `contacted`, and `resolved` are consistent with the most up-to-date student metrics.

## Considered Categories
To account for the fact that some courses may have optional assignments that shouldn't be used to determine which students are struggling, we have created an "allowlist" of considered categories. This feature allows instructors to toggle which categories of assignments should be included or excluded in metrics calculations.

### Configuring Considered Categories
The allowlist is located under the "Configurations" tab of the student metrics page. To toggle an assignment between "Included" and "Excluded," a user can press the arrow icon between the two lists. After pressing save, the new considered category settings will be updated and taken into consideration the next time you refresh the watchlist.

![Category Configuration](/images/metrics-category-config.jpg)
