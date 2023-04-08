# LTI Course Integration

LTI Course Integration is a feature that allows instructors to link a course on their University's chosen LTI platform such as Canvas to their Autolab course.

Currently, only course roster synchronization is supported.

## Installation
Follow these steps on the [installation page](/installation/lti_integration) in order to configure your Autolab deployment to support LTI Course Integration. You must be an Autolab Administrator in order to configure LTI linking.
Instructors can ignore these steps.

## Enabling LTI Course Linking
1. Log on to Autolab.
2. Then on your LTI platform, Install the LTI Platform's Autolab App to your corresponding course.
   The app should be set up by the administrators of your institution's LTI platform instance.
3. Launch the Autolab App from your LTI platform. For example, on Canvas,
   after Autolab app is installed on your course, click on the "Autolab" link in the course navigation tab.

    ![Canvas Course Navigation](/images/Canvas_Course_Navigation.png)

4. Once you are redirected to Autolab, choose which Autolab course to link with the LTI platform.

     ![Autolab Course Link UI](/images/lti_linking_page.png)

## LTI Course Synchronization

Once the LTI Launch flow is completed, instructors should be able to synchronize their course roster on Autolab with the LTI platform. 
Autolab will use the LTI platform as the source of truth when synchronizing its roster. Course synchronization
is currently only done **manually**.

In order to synchronize Autolab's course roster:

1. Navigate to the "Manage Course Users" page.
   The last time at which the roster was synchronized should be displayed next to the refresh button.

    ![Autolab Manage Course Users for LTI](/images/lti_manage_course_users.png)

2. Click the refresh button at the top right of the course roster. You will then be redirected to a confirmation screen.

3. Confirm the roster changes displayed in the roster table are correct, and then
   click "confirm" to apply the changes to your course roster.

    ![Autolab Course LTI Sync Roster Confirmation Page](/images/lti_sync_roster.png)

### LTI Course Synchronization Settings

1. Click on "Linked Course Settings" in the "Manage Course" page.
2. Click "Auto drop students not enrolled in linked course" to drop any students in the Autolab course that are not found in the LTI platform's course. 
3. Click "Unlink Course" to unlink the LTI platform course from the Autolab course.

![Autolab Course Linking Settings](/images/lti_linked_course_settings.png)



