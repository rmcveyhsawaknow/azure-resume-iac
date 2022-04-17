using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace Company.Function
{
    public class CosmosConstants
    {
        public const string COSMOS_DB_DATABASE_NAME = "azure-resume-click-count";
        public const string COSMOS_DB_CONTAINER_NAME = "Counter";
        public const string COSMOS_DB_Item_Document_Id = "1";
        public const string COSMOS_DB_Item_PartitionKey = "1";
    }
    
}
