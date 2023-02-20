# LTI Course Integration

LTI Course Integration is a feature that allows instructors to link a course on their University's chosen LTI platform such as Canvas to their Autolab course.

Currently, only course roster synchronization is supported.

## Installation
Follow these steps on the [installation page](/installation/lti_integration) in order to configure your Autolab deployment to support LTI Course Integration. You must be an Autolab Administrator in order to configure LTI linking.

## Enabling LTI Course Linking

1. Install the LTI Platform's Autolab App to your corresponding course on your LTI platform.
   The app should be set up by the administrators of your institution's LTI platform instance.
2. Begin an "LTI Launch" by launching the Autolab App on your LTI platform. For example, on Canvas,
   after Autolab app is installed on your course, click on the "Autolab" link in the course navigation tab.

    ![Canvas Course Navigation](/images/Canvas_Course_Navigation.png)

3. After initiating the launch process, you should be redirected to Autolab. The launch process may fail if you are not
   already logged into Autolab before initiating the launch. Once you are redirected to Autolab, you will be presented with
   a choice of which Autolab course to link with the LTI platform.

    ![Autolab Course Link UI](/images/lti_linking_page.png)

## LTI Course Synchronization

1. Once the LTI Launch flow is completed, instructors should be able to synchronize their course roster on Autolab with the LTI platform. 
   Autolab will use the LTI platform as the source of truth when synchronizing its roster.
   In order to synchronize Autolab's course roster, navigate to the "Manage Course Users" page. 
   There should be a "Linked Course Settings" button, along with a refresh button above the course roster. 
   The last time at which the roster was synchronized should be displayed next to the refresh button.

    ![Autolab Manage Course Users for LTI](/images/lti_manage_course_users.png)

2. Clicking on "Linked Course Settings" should display a modal which allows instructors to modify the functionality of course synchronization. 
   Currently one setting exists, which allows course synchronization to drop any students in the Autolab course that are
   not found in the LTI platform's course. There also is an option to unlink the LTI platform course from the Autolab course.

    ![Autolab Course Linking Settings](/images/lti_linked_course_settings.png)

3. Course synchronization is currently only initiated manually. 
   To initiate synchronization, click the refresh button at the top right of the course roster. Upon clicking the button, 
   you should be redirected to the page shown below. A table will be displayed showing all changes to the roster as a
   result of the synchronization, the same as with CSV roster upload.
   After checking the roster changes are correct, click "confirm" to apply the changes to your course roster.

    ![Autolab Course LTI Sync Roster Confirmation Page](/images/lti_sync_roster.png)

