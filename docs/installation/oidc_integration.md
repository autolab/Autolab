# OpenID Connect Integration Setup

OpenID Connect (OIDC) is a modern authentication protocol built on top of OAuth 2.0. It allows applications to verify user identities through an external identity provider (IdP). By implementing OIDC, you can enable students to sign into Autolab using a third-party identity provider (e.g., your institution's CAS).

This guide will walk you through setting up Autolab with your chosen IdP.

## Registration Process

First, register your Autolab instance with your IdP. While the registration process varies across different OIDC IdP implementations, there are several key parameters to configure:

- `redirect_url`: Must be set to `{scheme}://{your_autolab_instance}/auth/users/auth/openid_connect/callback`
  - Carefully specify the scheme (`http` or `https`) and `your_autolab_instance` to exactly match your deployment configuration and access URL.
- `client_id`:
  - Some IdPs allow you to specify a custom `client_id`, while others generate a unique identifier automatically. Either way, you'll need this ID for the next step.
- `client_secret`:
  - Upon registration completion, the IdP typically generates a unique and secure `client_secret`. Save this secret as you'll need it for the next step.

## Configuring Autolab for OpenID Connect

To enable OIDC in Autolab, create or modify the `Autolab/config/oauth_config.yml` file with the following configuration:

```yml
---
openid_connect:
  # Example configuration for Auth0 with sample credentials
  issuer: https://dev-s5lhkwr76zowpqbs.us.auth0.com/
  discovery: true
  uid_field: 'sub'
  client_auth_method: other
  scope: ['openid', 'email', 'profile']
  send_nonce: false
  client_options:
    identifier: 4RfbkCTRdfxQYs7vVABzHbWDwkpq58u6
    secret: O6vwmDkp31jE63r_VLR8SKvcIBFdrUqvnm1wv958DRJTFEiCOQsLU7haPobqmVwi
    redirect_uri: http://localhost:3303/auth/users/auth/openid_connect/callback
```

The configuration options under `openid_connect` correspond to the [`omniauth_openid_connect` package settings](https://github.com/omniauth/omniauth_openid_connect/tree/master?tab=readme-ov-file#options-overview).

Map the `client_options.identifier` and `client_options.secret` to the `client_id` and `client_secret` obtained during registration. For other fields, consult both the `omniauth_openid_connect` documentation and your IdP's documentation to determine the required fields and appropriate values.

### Required Claims

Ensure your IdP's ID token includes the following claims (configure via `scope` or your IdP's management console):

- `email`
- `name` OR `first_name` and `last_name`
  - If both `first_name` and `last_name` are provided, they will be used for the user's name
  - If only `name` is provided, it will be used as `first_name`, and `last_name` will be empty

After updating `oauth_config.yml` and restarting Autolab, you can verify the configuration in Autolab's **OAuth Integration** settings page:

![OIDC Setup Screenshot](/images/openid_setup.png)