# Annotations

Annotations is a feature introduced as part of the Speedgrader update to Autolab. It allows instructors and TAs to quickly leave comments and grade code at the same time. 

!!! attention "Non-Autograded Problems Only"
    Note that annotations can only be added to non-autograded problems. Specifically, a problem is non-autograded if there is no assigned score for that problem in the json outputted by the autograder

## Annotation types

### Line-based annotations

![Annotation Form](/images/annotations.png)

Hover over any line of the code and click on the green arrow, and the annotation form will appear. Add the comment, adjust the score, and select the targeted problem.

When the "Add to shared comment pool" option is checked, the comment will be saved to a shared comment pool.
When creating new annotations, shared comments matching what you have typed will be available via a dropdown list. Only the 50 most recently added shared comments will be displayed.

Note that the shared comment pool operates on a per-problem basis, so a shared comment for one problem will not be available when creating an annotation for another problem within the same assessment.
Additionally, the same shared comment pool is used by all instructors and course-assistants, so your shared comments will be available to other instructors and course-assistants, and vice-versa.

![Shared Comments](/images/shared_comments.png)

!!! attention "Deleting annotations"
    Note that shared comments are tied to the original annotation. If the original annotation is deleted, the comment will not persist in the shared comment pool.

### Global annotations

You can can also add a global annotation to a problem that is not tied to a specific line of code.

![Global Annotation Form](/images/annotations_global.png)

To do so, click on the "+" header button corresponding to the problem.

## Scoring Behavior

There are two intended ways for course instructors to use the add annotation features. Deductions from maximum ("negative grading"), or additions to zero ("positive grading").

The default setting is negative grading, but positive grading can be enabled under `Edit Assessment > Problems`.

![Positive Grading](/images/positive_grading.png)

### Negative Grading

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question. Then when the grader is viewing the code, add a negative score, such as `-5` into the score field, to deduct from the maximum. This use case is preferred when grading based on a rubric, and the score is deducted for each mistake.

The maximum score can be `0` if the deductions are meant to be penalties, such as for poor code style or violation of library interfaces.

### Positive Grading

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question. Then when the grader is viewing the code, add a positive score, such as `5` to the score field, to add to the score. This use case is preferred when giving out bonus points.

## Interaction with Gradesheet

We have kept the ability the edit the scores in the gradesheet, as we understand that there are instances in which editing the gradesheet directly is much more efficient and/or needed. However, this leads to an unintended interaction with the annotations.

In particular, modifications on the gradesheet itself will override all changes made to a problem by annotations, but the annotations made will still remain. 

A example would be, if the `max_score` of a problem is `10`. A grader adds an annotation with `-5` score to that problem (so the score is now `10-5=5`). Then if the same/another grader changes the score to `8` on the gradesheet, the final score would be `8`.

**Recommendation**

It is much preferred to grade using annotations whenever possible,
as it provides a better experience for the students who will be able to identify the exact line at which the mistake is made. Gradesheet should be used in situations where the modification is non-code related.