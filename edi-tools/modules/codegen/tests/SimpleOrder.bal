
import ballerina/edi;

public isolated function fromEdiStringSimpleOrder(string ediText) returns SimpleOrder|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json dataJson = check edi:fromEdiString(ediText, ediSchema);
    return dataJson.cloneWithType();
}

public isolated function toEdiString(SimpleOrder data) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:toEdiString(data, ediSchema);    
} 

public isolated function getSchema() returns edi:EdiSchema|error {
    return edi:getSchema(schemaJson);
}

public isolated function fromEdiStringWithSchema(string ediText, edi:EdiSchema schema) returns SimpleOrder|error {
    json dataJson = check edi:fromEdiString(ediText, schema);
    return dataJson.cloneWithType();
}

public isolated function toEdiStringWithSchema(SimpleOrder data, edi:EdiSchema ediSchema) returns string|error {
    return edi:toEdiString(data, ediSchema);    
}

public type Header_Type record {|
   string? code = "HDR";
   string orderId?;
   string organization?;
   string date?;
|};

public type Items_Type record {|
   string? code = "ITM";
   string item?;
   int? quantity?;
|};

public type SimpleOrder record {|
   Header_Type? header?;
   Items_Type[] items = [];
|};



final readonly & json schemaJson = {"name":"SimpleOrder", "delimiters":{"segment":"~", "field":"*", "component":":", "repetition":"^"}, "segments":[{"code":"HDR", "tag":"header", "fields":[{"tag":"code"}, {"tag":"orderId"}, {"tag":"organization"}, {"tag":"date"}]}, {"code":"ITM", "tag":"items", "maxOccurances":-1, "fields":[{"tag":"code"}, {"tag":"item"}, {"tag":"quantity", "dataType":"int"}]}]};
    