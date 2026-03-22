// Runtime configuration — overwritten by CI/CD pipeline during deployment.
// See the 'Generate Frontend Config' step in the deployment workflows.
// For local development, set defined_FUNCTION_API_BASE to your Function App URL, e.g.:
//   var defined_FUNCTION_API_BASE = 'https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter';
var defined_FUNCTION_API_BASE = '';

// Application Insights connection string — injected by CI/CD from the deployed App Insights resource.
// For local development, copy the connection string from the Azure Portal App Insights resource overview.
var defined_APPINSIGHTS_CONNECTION_STRING = '';

// Microsoft Clarity project ID — injected by CI/CD from GitHub Secrets (repository or environment level).
// To set up Clarity: create a free account at https://clarity.microsoft.com, create a project,
// and store the project ID as CLARITY_PROJECT_ID in your GitHub repository or environment secrets.
// Environment secrets (e.g. on 'development' or 'production') work alongside repo-level secrets.
var defined_CLARITY_PROJECT_ID = '';

// Stack version and environment — injected by CI/CD from the workflow's stackVersion and
// stackEnvironment env vars. Displayed in the site footer as a deployment indicator.
// For local development, these remain empty and the footer shows a "Local Dev" fallback.
var defined_STACK_VERSION = '';
var defined_STACK_ENVIRONMENT = '';
