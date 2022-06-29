## Annotations

Annotations is a feature introduced as part of the Speedgrader update to Autolab. It allows instructors and TAs to quickly leave comments and grade code at the same time. 

![Annotation Form](/images/annotations.png)

Hover over any line of the code and click on the green arrow, and the annotation form will appear. Add the comment, adjust the score, and select the targeted problem.

!!! attention "Non-Autograded Problems Only"
    Note that annotations can only be added to non-autograded problems. Specifically, a problem is non-autograded if there is no assigned score for that problem in the json outputted by the autograder

### Scoring Behavior

There are two intended ways for course instructors to use the add annotation features. Deductions from maximum, or additions from zero.

**Deductions from maximum**

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question. Then when the grader is viewing the code, add negative score, such as `-5` into the score field, to deduct from the maximum. This use case is preferred when grading based on a rubric, and the score is deducted for each mistake.

The maximum score can be `0` if the deductions are meant to be penalties, such as for poor code style or violation of library interfaces.

**Additions from zero**

Set a `max_score` either programmatically, or under `Edit Assessment > Problems` for the particular non-autograded question to `0`. When the grader is viewing the code, add positive scores, such as `5` to the score field, to add to the score. This use case is preferred when giving out bonus points.

### Interaction with Gradesheet

We have kept the ability the edit the scores in the gradesheet, as we understand that there are instances in which editing the gradesheet directly is much more efficient and/or needed. However, this leads to an unintended interaction with the annotations.

In particular, modifications on the gradesheet itself will override all changes made to a problem by annotations, but the annotations made will still remain. 

A example would be, if the `max_score` of a problem is `10`. A grader adds an annotation with `-5` score to that problem (so the score is now `10-5=5`). Then if the same/another grader changes the score to `8` on the gradesheet, the final score would be `8`.

**Recommendation**

It is much preferred to grade using annotations whenever possible,
as it provides a better experience for the students who will be able to identify the exact line at which the mistake is made. Gradesheet should be used in situations where the modification is non-code related.