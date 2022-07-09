# Overview

The web interface that has served us well for many years is no longer the only way to use Autolab. With the API, developers will be able to help make Autolab more versatile and convenient: Whether it be with a mobile app, a command line tool, a browser extension, or something we've never even thought of.

For students and instructors who only plan to use Autolab, try out the [Autolab CLI](/command-line-interface/).

The Autolab REST API allows developers to create clients that can access features of Autolab on behalf of Autolab users.

V1 of the API allows clients to:

-   Access basic user info
-   View courses and assessments
-   Submit to assessments
-   View scores and feedback
-   Manage course enrollments

## Authorization

All endpoints of the Autolab API requires client authentication in the form of an access token. To obtain this access token, clients must obtain authorization from the user.

Autolab API uses the standard <a href="https://tools.ietf.org/html/rfc6749" target="_blank">OAuth2</a> <a href="https://tools.ietf.org/html/rfc6749#section-4.1" target="_blank">Authorization Code Grant</a> for user authorization.

For clients with no easy access to web browsers (e.g. console apps), an alternative <a href="https://tools.ietf.org/html/draft-ietf-oauth-device-flow-07" target="_blank">device flow</a>-based authorization method is provided as well.

To register an API application, one needs to have an admin privileges, and then visit `Manage Autolab > Manage API application`. Refer to [Scopes](#scopes) for the available scopes. To understand how to authorize and unauthorize clients as a user, go to [Managing Authorized Apps](/api-managing-authorized-apps/)
### Authorization Code Grant Flow (OAuth2)

- **OAuth Authorization Request Endpoint**: `/oauth/authorize`
- **OAuth Access Token Endpoint**: `oauth/token`

The authorization code grant consists of 5 basic steps:

1. Client directs the user to the authorization request endpoint via a web browser.
2. Authorization server (Autolab) authenticates the user.
3. If user grants access to the client, the authorization server provides an "authorization code" to the client.
4. Client exchanges the authorization code for an access token from the access token endpoint.
5. Client uses the access token for subsequent requests to the API.

<a href="https://tools.ietf.org/html/rfc6749#section-4.1" target="_blank">Section 4.1 of RFC 6749</a> details the parameters required and the response clients can expect from these endpoints.

Autolab API provides a refresh token with every new access token. Once the access token has expired, the client can use the refresh token to obtain a new access token, refresh token pair. Details are also provided in RFC 6749 <a href="https://tools.ietf.org/html/rfc6749#section-6" target="_blank">here</a>.

### Device Flow (Alternative)

For devices that cannot use a web browser to obtain user authorization, the alternative device flow approach circumvents the first 3 steps in the authorization code grant flow. Instead of directing a user to the authorization page directly, the client obtains a user code that the user can enter on the Autolab website from any device. The website then takes the user through the authorization procedure, and returns the authorization code to the client. The client can then use this code to request an access token from the access token endpoint as usual.

Note that this is different from the "device flow" described in the Internet Draft linked above.

#### Obtaining User Code

Request Endpoint: `GET /oauth/device_flow_init`

Parameters:

-   client_id: the client_id obtained when registering the client

Success Response:

-   device_code: the verification code used by the client (should be kept secret from the user).
-   user_code: the verification code that should be displayed to the user.
-   verification_uri: the verification uri that the user should use to authorize the client. By default is `/activate`

The latter two should be displayed to the user.

#### Obtaining Authorization Code

After asking the user to enter the user code on the verification site, the client should poll the device_flow_authorize endpoint to find out if the user has completed the authorization step.

Request Endpoint: `GET /oauth/device_flow_authorize`

Parameters:

-   client_id: the client_id obtained when registering the client
-   device_code: the device_code obtained from the device_flow_init endpoint

Failure Responses:

-   400 Bad Request: {error: authorization_pending}

    The user has not yet granted or denied the authorization request. Please try again in a while.

-   429 Too Many Requests: {error: Retry later}

    The client is polling too frequently. Please wait for a while before polling again.

    The default rate limit is once every 5 seconds.

Success Response:

-   code: the authorization code that should be used to obtain an access token.

The client could then perform steps 4 and 5 of the Authorization Code Grant Flow.

## Getting Started

Autolab requires all client applications to be registered clients. Upon registration, a client_id and client_secret pair will be provided to the developers for use in the app as identification to the server. Please contact the administrators of your specific Autolab deployment for registration.

!!! warning "Security Concerns"
    Please make sure to keep the client_secret secret. Leaking this code may allow third-parties to impersonate your app.

### Scopes

The scopes of an API client specifies the permissions it has, and must be specified during client registration (can be modified later). Currently, Autolab offers the following scopes for third-party clients:

-   user_info: Access your basic info (e.g. name, email, school, year).
-   user_courses: Access your courses and assessments.
-   user_scores: Access your submissions, scores, and feedback.
-   user_submit: Submit to assessments on your behalf.
-   instructor_all: Access admin options of courses where you are an instructor.

**Example usages**

-   If your app only wants to use the API for quick user authentication, you only need the 'user_info' scope.
-   If you want to develop a mobile client for Autolab that allows students to view their upcoming assessments, you may ask for 'user_info' and 'user_courses'.
-   If you want to write a full desktop client that users can use to submit to assessments and view their grades, you may ask for all 5 scopes.

Of course, these are only examples. We can't wait to see what new usages of the API you may come up with! We just recommend that you only ask for the scopes you need as the users will be shown the required scopes during authorization, and it gives them peace of mind to know that an app doesn't ask for excessive permissions.
