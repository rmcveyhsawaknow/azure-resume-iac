# azure-resume

My own Azure resume, following [ACG project video](https://learn.acloud.guru/series/acg-projects/view/403). Created on my Windows 11 MinisForum EliteMini HX90 pc, using [Visual Studio Code](https://code.visualstudio.com/). Extended version of the project created by [Drew Davis](https://github.com/davisdre/azure-resume/) with IaC to deploy all Azure resources.

## Software I needed for this project

- [Visual Studio Code](https://code.visualstudio.com/)
- [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cwindows%2Ccsharp%2Cportal%2Cbash)
- [Visual Studio Code Extension: Azure Functions](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [dotnet core 3.1](https://dotnet.microsoft.com/en-us/download/dotnet/3.1)
**Make sure to get 3.1 version, else there will be newtonsoft errors later on in the counter.cs and getresumecounter.cs
- [NuGet Microsoft.Azure.WebJobs.Extensions.CosmosDB](https://www.nuget.org/packages/Microsoft.Azure.WebJobs.Extensions.CosmosDB#dotnet-cli)
- [Visual Studio Code Extension: Azure Storage](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurestorage)

## Setup Steps

- Create Azure Application Registration

```text

az login

az account set --name subName

az ad sp create-for-rbac --name <somethingThatMakesSenseToYou> --role contributor --scopes /subscriptions/<yourSubscriptionId> --sdk-auth 


```

- Create a gitHub reposity secret named AZURE_RESUME_GITHUB_SP   and input json value from above az command

- Modify the environment variables in ./.github/workflows/develop-full-stack.yml and ./.github/workflows/prod-full-stack.yml to suit your needs

  - I use godaddy for dns and have delegated to a dns zone in a central resource within the resource group listed in the rgDNS env variable listed below. The bicep will fail if you don't do something similar.

```text

    env: 
    dnsZone: 'ryanmcvey.me'
    stackVersion: 'v1'
    stackEnvironment: 'dev'
    stackLocation: 'eastus'
    stackLocationCode: 'us1'
    AppName: 'resume'
    AppBackendName: 'resumecounter'
    tagCostCenter: 'a1b2c3'
    rgDns: 'glbl-ryanmcveyme-v1-rg'

```

- after the stack deploys, need to retrieve a few values and commit for new release to configure the app

  - ./frontend/main.js , need to input the applicable functionApiUrl
  - ./frontend/js/azure_app_insights.js , need to input applicable connection string
  - via azure portal in the backend resource group, connect to cosmos db Data Explorer and create the db/container/item value

```json
"id": "1",
"count": 0
```

- once the github action runs again, the full stack is complete and you should be able to access your functioning app at something like <https://resume.ryanmcvey.me>

- TODO , need to find a way to automate the injection of the manual steps above
