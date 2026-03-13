using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Moq;
using System.IO;
using Xunit;

namespace tests
{
    public class TestCounter
    {
        [Fact]
        public void Http_trigger_should_return_known_string()
        {
            var counter = new Company.Function.Counter
            {
                Id = "1",
                Count = 2
            };

            var mockContext = new Mock<FunctionContext>();
            var mockRequest = new Mock<HttpRequestData>(mockContext.Object);
            var mockResponse = new Mock<HttpResponseData>(mockContext.Object);
            mockResponse.SetupProperty(r => r.StatusCode);
            mockResponse.SetupProperty(r => r.Body, new MemoryStream());
            mockResponse.Setup(r => r.Headers).Returns(new HttpHeadersCollection());
            mockRequest.Setup(r => r.CreateResponse()).Returns(mockResponse.Object);

            var logger = new Mock<ILogger<Company.Function.GetResumeCounter>>();
            var function = new Company.Function.GetResumeCounter(logger.Object);

            var result = function.Run(mockRequest.Object, counter);

            Assert.Equal(3, result.UpdatedCounter.Count);
        }
    }
}