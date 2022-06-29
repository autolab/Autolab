# Github Integration Setup

In order to setup Github submission, you will first need to create a Github Application and get its corresponding Client ID and Client Secrets. After that, you only need to update the `.env` file with the information. The full steps are given in the following sections.

## Creating your Github Application

1. Navigate to the [Github developer settings](https://github.com/settings/developers) in order to create a new OAuth app

2. Fill in the required form fields:
    - Homepage URL should be the URL that Autolab will be served on (i.e `https://my-autolab-deployment.com`). 
    - Authorization callback URL is the URL that Github will make a callback to after authentication, which must be the homepage URL appended with `/users/github_oauth_callback` (i.e [https://my-autolab-deployment.com/users/github_oauth_callback)
    - Application name and description should be something helpful to allow students to trust the OAuth application (i.e `CMU Autolab`)

    An example:

    ![Github OAuth Setup](/images/github_oauth_setup.png)

3. After registering the application, you will now have a Client ID for your application. Create a Client Secret for the Client ID, you should see something like the following:

    ![Github OAuth Secrets](/images/github_oauth_secrets.png)


## Configuring Github Integration for Autolab
1. Ensure that you already have the Github application credentials set up [based on the previous section](#creating-your-github-application)

2. If you do not have a `.env` file in your Autolab root yet (it may not be present on older installations), create it by running the following script from the Autolab root directory:

        :::bash
    	./bin/initialize_secrets.sh

3. Open up `.env` in your favorite editor, and update `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` to use the client ID and client secrets generated previously:

        :::bash
        GITHUB_CLIENT_ID=replace_with_your_client_ID
        GITHUB_CLIENT_SECRET=replace_with_your_client_secret

## Verifying Github Integration
In order to verify whether your deployment has been setup correctly,

1. Login as an Autolab administrator user

2. Navigate to the Manage Autolab tab on the top navigation bar

3. Select Github Integration link. It will detect whether your credentials have been supplied correctly by testing against the API limits that you are entitled to, and report whether your installation is successfully integrated with Github.