# Your frontend live here

## Step 1 - main.js

- in the main.js need to include the specific function app url and key, example below

```js
window.addEventListener('DOMContentLoaded', (event) =>{
    getVisitCount()
})

const functionApiUrl = 'https://functionAppName.azurewebsites.net/api/GetResumeCounter?code=key';
// const functionApiUrl = 'http://localhost:7071/api/GetResumeCounter';

const getVisitCount = () => {
    let count = 30;
    fetch(functionApiUrl).then(response => {
        return response.json()
    }).then(response =>{
        console.log("Website called function API.");
        count = response.count;
        document.getElementById("counter").innerText = count;
    }).catch(function(error){
        console.log(error);
    });
    return count;
}
````

## Step 2 - setup CORS in backend\api\local.settings.json for local dev/testing

- add this setting

```json

{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "AzureResumeConnectionString":"AccountEndpoint=https://cosmosdbname.documents.azure.com:443/;AccountKey=#####;"
    // TODO Move this to a Key Vault
    
  },
  "Host":
  {
    "CORS": "*"
  }
}

```

- terminal -> backend\api -> func host start

## Step 3 - deploy the function app to azure

- azure extensions, functions

- highlight Local Project, cloud up arrow to deploy

- inputs for new function app resource, storage account, app insights

- subscription, create new (advanced), name the FA, .net core 3.1, Linux, consumption, create storage account, create app insights name

## Step 4 - configure function app

- copy cosmos connection string from local.settings.json to function app settings in portal
  
  - find function app, configuration, add name and value, SAVE
    - AzureResumeConnectionString
    - AccountEndpoint=https://name.documents.azure.com:443/;AccountKey=key;
  - "Make this a Key Vault secret later"

- get the function url add to main.js, const functionApiUrl =

- enable CORS on Function App in portal, with no value in list for now

- grab the function url w/ key, hit in browser, set value increment....

## Step 5 - Deploy frontend to storage

- Get Azure Storage VS Code extension
  - right click Frontend dir, deploy to a static website via Azure storage
  - sub, new sa (advanced), name, static website yes, index.html, location, bam...

- At this point counter does not work on page, so update the function app CORS setting with the static website URL

## Step 6 - Deploy CDN for cache, custom domain, SSL/TLS

- storage account, azure cdn
  - new endpoint, name, standard MS, static website
  - update FA CORS, test, bam...
  - note!!! default CDN profile will not accept HTTP, use this ref to set rule to redirect 302 to HTTPS <https://docs.microsoft.com/en-us/azure/cdn/cdn-standard-rules-engine>

## Step 7 - Custom DNS

- I use godaddy, so need to create CNAME at something other than apex root domain, I used resume.ryanmcvey.me and set value to Azure CDN endpoint

- Back on the Azure storage account, Azure CDN, Custom Domains
  - Add custom domain, resume.ryanmcvey.me
  - Enable custom domain HTTPS, CDN Managed TLS 1.2, this can take a bit
  - update FA CORS with <https://resume.ryanmcvey.me>, bam...

<!-- Resume at minute 48 of the video @ <https://learn.acloud.guru/series/acg-projects/view/403> -->
