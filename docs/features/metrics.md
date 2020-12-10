# Metrics

The metrics feature seeks to identify students who might be struggling in class by tracking metrics that signify possible risks. The feature is developed partially in response to the increasing number of classes done remotely in 2020, to help instructors find at risk students whom they should reach out to earlier in the course. Identifying at-risk students early would provide a better chance of getting them back on track in the course.


## Usage Flow

We envision the feature to be used by the instructors in this order. They would:

1. Set up their course and assignments as per usual
1. Set up [Risk Metrics](#risk-metrics) at the start of the course
1. Be notified of new at risk students in their [Watchlist](#watchlist) on their course page
1. Visit the [Watchlist](#watchlist), contact students if necessary, using it as a work list at the same time
1. Refine the [Risk Metrics](#risk-metrics) as the course progresses

## Risk Metrics

![Metrics](/images/risk_metrics.png)

From our interviews with instructors, we understand that different courses have different measures of whether a student is at risk. As such, a set of risk conditions together will define the course's risk metrics. We intend to add more conditions to the risk metrics in the future. Feel free to suggest them via our [GitHub Issues](https://github.com/autolab/Autolab/issues) page.

### Risk Condition Rationale

The conditions are designed to capture different characteristics of a possibly at risk student. In the sections that follow we attempt to explain the rationale behind each condition to aid with selecting the risk conditions.

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