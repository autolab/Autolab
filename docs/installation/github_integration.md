# Github Integration Setup

## Creating your Github Application

<!-- TODO: the screenshots below should be updated and use pictures from our own repo, instead of Github -->

1. Navigate to https://github.com/settings/developers in order to create a new OAuth app

2. Homepage URL should be the URL that Autolab will be served on (i.e https://nightly.autolabproject.com). Authorization callback URL is the URL that Github will make a callback to after authentication, which must be the homepage URL appended with `/users/github_oauth_callback` (i.e https://nightly.autolabproject.com/users/github_oauth_callback)


See example:
![DeepinScreenshot_select-area_20211113132623](https://user-images.githubusercontent.com/9707110/141655049-396bd95f-7977-49f4-8e55-f15522575afd.png)

3. After registering the application, you should now have a Client ID for your application. Create a Client Secret as well, you should see the following:

![DeepinScreenshot_select-area_20211113133047](https://user-images.githubusercontent.com/9707110/141655219-e8878062-31d4-4ed6-b536-1b6718283dbe.png)



## Configuring Github Integration for Autolab
First, ensure that you already have the Github application credentials set up [based on the previous section](#creating-your-github-application)

If you do not have a `.env` file in your Autolab root yet (may not be present on older installations), create it by running the following script from the Autolab root directory:

        :::bash
        ./bin/initialize_secrets.sh

Open up `.env` in your favorite editor, and update `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` to use the client ID and client secrets that you generated previously:

        :::bash
	GITHUB_CLIENT_ID=replace_with_your_client_ID
	GITHUB_CLIENT_SECRET=replace_with_your_client_secret

## Verifying Github Integration
In order to verify whether your deployment has been setup correctly,

1. Login as an Autolab administrator user

2. Navigate to the Manage Autolab tab on the top navigation bar

3. Select Github Integration link. It will detect whether your credentials have been supplied correctly by testing against the API limits that you are entitled to, and report whether your installation is successfully integrated with Github.