using System.Net;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace Company.Function
{
    public class GetResumeCounter
    {
        private readonly ILogger<GetResumeCounter> _logger;

        public GetResumeCounter(ILogger<GetResumeCounter> logger)
        {
            _logger = logger;
        }

        [Function("GetResumeCounter")]
        public MultiResponse Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req,
            [CosmosDBInput(
                databaseName: CosmosConstants.COSMOS_DB_DATABASE_NAME,
                containerName: CosmosConstants.COSMOS_DB_CONTAINER_NAME,
                Connection = "AzureResumeConnectionStringPrimary",
                Id = CosmosConstants.COSMOS_DB_Item_Document_Id,
                PartitionKey = CosmosConstants.COSMOS_DB_Item_PartitionKey)] Counter counter)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");

            counter.Count += 1;

            var jsonToReturn = JsonSerializer.Serialize(counter);

            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "application/json; charset=utf-8");
            response.WriteString(jsonToReturn);

            return new MultiResponse
            {
                HttpResponse = response,
                UpdatedCounter = counter
            };
        }
    }

    public class MultiResponse
    {
        [HttpResultAttribute]
        public HttpResponseData HttpResponse { get; set; }

        [CosmosDBOutput(
            databaseName: CosmosConstants.COSMOS_DB_DATABASE_NAME,
            containerName: CosmosConstants.COSMOS_DB_CONTAINER_NAME,
            Connection = "AzureResumeConnectionStringPrimary")]
        public Counter UpdatedCounter { get; set; }
    }
}
