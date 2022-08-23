# Sitecore Content Hub integration for XM Cloud

## Create user in Sitecore Content Hub

Create user as per [these](https://doc.sitecore.com/xp/en/developers/connect-for-ch/50/connect-for-content-hub/create-a-user-in-sitecore-content-hub.html) instructions

## Add connection strings

Add environment variables to your XM Cloud environment.
Use POST ​/api​/environments​/v1​/{environmentId}​/variables​/{variable} request on [API](https://xmclouddeploy-api.sitecorecloud.io/swagger/index.html)
Variables should be in the following format:
```
[
    {
        "name": "Sitecore_ConnectionStrings_CMP_dot_ContentHub",
        "value": "ClientId=;ClientSecret=;UserName=;Password=;URI=;",
        "secret": true
    },
    {
        "name": "Sitecore_ConnectionStrings_CMP_dot_ServiceBusEntityPathIn",
        "value": "Endpoint=sb://xxx.servicebus.windows.net/;SharedAccessKeyName=;SharedAccessKey=;EntityPath=",
        "secret": true
    },
    {
        "name": "Sitecore_ConnectionStrings_CMP_dot_ServiceBusEntityPathOut",
        "value": "Endpoint=sb://xxx.servicebus.windows.net/;SharedAccessKeyName=;SharedAccessKey;EntityPath=",
        "secret": true
    },
    {
        "name": "Sitecore_ConnectionStrings_CMP_dot_ServiceBusSubscription",
        "value": "Sitecore",
        "secret": false
    },
    {
        "name": "Sitecore_ConnectionStrings_DAM_dot_ContentHub",
        "value": "ClientId=;ClientSecret=;UserName=;Password=;URI=;",
        "secret": true
    },
    {
        "name": "Sitecore_ConnectionStrings_DAM_dot_ExternalRedirectKey",
        "value": "Sitecore",
        "secret": false
    },
    {
        "name": "Sitecore_ConnectionStrings_DAM_dot_SearchPage",
        "value": "https://<Content Hub Instance host>/en-us/sitecore-dam-connect/approved-assets",
        "secret": false
    }
]
```
Values for Sitecore_ConnectionStrings_CMP_dot_ContentHub and Sitecore_ConnectionStrings_DAM_dot_ContentHub can be set up with [these](https://doc.sitecore.com/xp/en/developers/connect-for-ch/50/connect-for-content-hub/add-connection-strings-for-cmp-to-your-sitecore-instance.html) instructions.
Values for Sitecore_ConnectionStrings_CMP_dot_ServiceBusEntityPathIn and Sitecore_ConnectionStrings_CMP_dot_ServiceBusEntityPathOut can be set up with [these](https://doc.sitecore.com/xp/en/developers/connect-for-ch/50/connect-for-content-hub/create-a-sitecore-content-hub-action.html) instructions.

## Configure CORS for Content Hub

Add your Sitecore Instance URL to Content Hub CORS settings with [these](https://doc.sitecore.com/xp/en/developers/connect-for-ch/50/connect-for-content-hub/configure-cors-for-dam.html) instructions.

## Replace placeholders in src/platform/web.config

## Test your set up

Test your set up with [these](https://doc.sitecore.com/xp/en/developers/connect-for-ch/50/connect-for-content-hub/display-assets.html) instructions