# Managing Authorized Apps

With the advent of the API, developers can now create new, more versatile and convenient ways of accessing Autolab.

What this means for users is that you can now use third-party programs to access Autolab to view assignments, download handouts, and even submit your solutions. Rest assured that all developers and their clients will be manually vetted by our team to ensure quality and safety. However, it is still important that you understand how clients interact with your account.

### Terminology

-   user: a user of Autolab (student/instructor)
-   client: a program that uses the Autolab api
-   developer: a person that develops clients

## Granting access

As a user of Autolab, when you want to use a client for the first time, you need to grant access to the client so that it can interact with Autolab for you.

-   **Easy Activation**: Clients that have access to a web browser (e.g. mobile apps, web apps) will **redirect** the user directly to the Grant Permissions page on Autolab.
-   **Manual Activation**: Clients that _don't_ have access to a web browser (e.g. command line programs) will present to the user a **6-digit code** (case sensitive) that should be entered on the Autolab website.

_Note_: Third-party clients never ask for your Autolab username or password. Never enter them anywhere else except on the Autolab website (always check the page url before entering your credentials).

![API Manual Activation Page](/images/api/api-activate.png)
_Manual activation page_

When you enter the code on the website and click "Activate", you will be taken to the Grant Permissions page.

![API Grant Permissions Page](/images/api/api-permissions.png)
_API Grant Permissions Page_

This page shows you all the permissions the client requests. Click 'approve' to grant these permissions to this client.

## Reviewing your authorized clients

As a user, you can review all the clients that you've granted access to on the Manage Authorized Clients page. Click on the menu at the upper right corner, then click on 'Account'. At the bottom of the page you'll find the 'Manage Authorized Clients' link.

![API Manage Authorized Clients Page](/images/api/api-manage-clients.png)
_Manage all the clients that currently have access to your account_

You can view the permissions that each client has (hover over the icon to see a description of each permission). You can also click 'Revoke' at any time to revoke the access of a client immediately.
