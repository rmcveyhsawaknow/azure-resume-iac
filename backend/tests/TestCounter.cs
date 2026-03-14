using System.IO;
using System.Net;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace tests
{
    public class TestCounter
    {
        private readonly Mock<ILogger<Company.Function.GetResumeCounter>> _mockLogger;
        private readonly Company.Function.GetResumeCounter _function;

        public TestCounter()
        {
            _mockLogger = new Mock<ILogger<Company.Function.GetResumeCounter>>();
            _function = new Company.Function.GetResumeCounter(_mockLogger.Object);
        }

        private static (Mock<HttpRequestData> request, Mock<HttpResponseData> response) CreateMockHttpContext()
        {
            var mockContext = new Mock<FunctionContext>();
            var mockRequest = new Mock<HttpRequestData>(mockContext.Object);
            var mockResponse = new Mock<HttpResponseData>(mockContext.Object);
            mockResponse.SetupProperty(r => r.StatusCode);
            mockResponse.SetupProperty(r => r.Body, new MemoryStream());
            mockResponse.Setup(r => r.Headers).Returns(new HttpHeadersCollection());
            mockRequest.Setup(r => r.CreateResponse()).Returns(mockResponse.Object);
            return (mockRequest, mockResponse);
        }

        [Fact]
        public void Http_trigger_should_increment_counter()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 2 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            Assert.Equal(3, result.UpdatedCounter.Count);
        }

        [Fact]
        public void Http_trigger_should_increment_counter_from_zero()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 0 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            Assert.Equal(1, result.UpdatedCounter.Count);
        }

        [Fact]
        public void Http_trigger_should_return_ok_status()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 0 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            Assert.Equal(HttpStatusCode.OK, result.HttpResponse.StatusCode);
        }

        [Fact]
        public void Http_trigger_should_return_json_content_type()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 0 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            Assert.Contains("application/json; charset=utf-8", result.HttpResponse.Headers.GetValues("Content-Type"));
        }

        [Fact]
        public void Http_trigger_should_return_updated_counter_as_json()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 5 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            result.HttpResponse.Body.Position = 0;
            using var reader = new StreamReader(result.HttpResponse.Body);
            var body = reader.ReadToEnd();
            var deserialized = JsonSerializer.Deserialize<Company.Function.Counter>(body);

            Assert.NotNull(deserialized);
            Assert.Equal("1", deserialized.Id);
            Assert.Equal(6, deserialized.Count);
        }

        [Fact]
        public void Http_trigger_updated_counter_should_reference_same_object()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 10 };
            var (mockRequest, _) = CreateMockHttpContext();

            var result = _function.Run(mockRequest.Object, counter);

            Assert.Same(counter, result.UpdatedCounter);
        }

        [Fact]
        public void Counter_model_should_serialize_with_lowercase_properties()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 42 };

            var json = JsonSerializer.Serialize(counter);

            Assert.Contains("\"id\":", json);
            Assert.Contains("\"count\":", json);
            Assert.DoesNotContain("\"Id\":", json);
            Assert.DoesNotContain("\"Count\":", json);
        }

        [Fact]
        public void Counter_model_should_round_trip_serialize()
        {
            var counter = new Company.Function.Counter { Id = "1", Count = 99 };

            var json = JsonSerializer.Serialize(counter);
            var deserialized = JsonSerializer.Deserialize<Company.Function.Counter>(json);

            Assert.NotNull(deserialized);
            Assert.Equal(counter.Id, deserialized.Id);
            Assert.Equal(counter.Count, deserialized.Count);
        }
    }
}