# Proposal: EDI

_Owners_: @chathurace @ruks  
_Reviewers_:     
_Created_: 2023/03/31  
_Updated_:   
_Issue_: [#495](https://github.com/ballerina-platform/ballerina-extended-library/issues/495)

## Summary

To enable EDI integrations, having EDI file processing capabilities is essential. This library provides functionalities
to parse EDI files and write additional logic on those data.

## Module Overview

EDI module provides functionality to read EDI files and map those to Ballerina records or 'json' type. Mappings for EDI
files have to be provided in json format. Once a mapping is provided, EDI module can generate Ballerina records to hold
data in any EDI file represented by that mapping. Then the module can read EDI files (in text format) in to generated
Ballerina records or as json values, which can be accessed from Ballerina code.

## EDI file structure

Here is a simple sample for EDI file

```
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12
ITM*A-45*100
ITM*D-10*58
ITM*K-80*250
ITM*T-46*28
```

An EDI file is a binary computer file that contains data arranged in units called data elements. Data elements are
separated by element terminators(*), and a group of data elements makes up a data segment. Data segments are separated
by
segment terminators(~).

## EDI mapping file

In order to parse an EDI document to ballerina readable code, an EDI mapping file is required. The mapping file can be
manually implemented by a human for a given EDI document or can be converted from an existing definition like `Smooks`
or `ESL`.

Here is a sample EDI mapping file(edi-mapping1.json) for the above EDI document.

```json
{
  "name": "SimpleOrder",
  "delimiters": {
    "segment": "~",
    "field": "*"
  },
  "segments": {
    "HDR": {
      "tag": "header",
      "fields": [
        {
          "tag": "orderId"
        },
        {
          "tag": "organization"
        },
        {
          "tag": "date"
        }
      ]
    },
    "ITM": {
      "tag": "items",
      "maxOccurances": -1,
      "fields": [
        {
          "tag": "item"
        },
        {
          "tag": "quantity",
          "dataType": "int"
        }
      ]
    }
  }
}
```

Above mapping can be used to parse EDI documents with one HDR segment (mapped to "header") and any number of ITM
segments (mapped to "items"). HDR segment contains three fields, which are mapped to "orderId", "organization" and "
date". Each ITM segment contains two fields mapped to "item" and "quantity". Below is a sample EDI document that can be
parsed using the above mapping (let's assume that the below EDI is saved in edi-sample1.edi file).

## Converting Smooks mapping files to Ballerina mappings

Smooks library is commonly used for parsing EDI files. Therefore, many organizations have already created Smooks
mappings for their EDIs. Ballerina EDI module can convert such Smooks mapping to Ballerina compatible mappings so that
organizations can start using Ballerina for EDI processing without redoing any mappings.

The following command converts Smooks EDI mapping to Ballerina EDI mapping:

```shell
bal smooksToBal <Smooks mapping xml file path> <Ballerina mapping json file path>
```

For example, the below command converts the Smooks mapping for
EDIFACT [Invoice EDI](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.xml) to a
Ballerina compatible JSON mapping.

```shell
bal smooksToBal d3a-invoic-1/mapping.xml d3a-invoic-1/mapping.json
```

Generated JSON mapping is
shown [here](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.json).

Then we can use the generated JSON mapping to generate Ballerina records and to parse invoice EDIs as shown above.

## Converting EDI Schema Language (ESL) files to Ballerina compatible mappings

ESL is another format used in EDI mapping files. The Ballerina EDI tool can convert ESL mappings into Ballerina compatible
mappings, so that it is possible to generate Ballerina code and process EDIs defined in ESLs without having to rework on
mappings.

The following command converts ESL files to Ballerina EDI mappings. Note that segment definitions are given in a separate
file, which is usually shared by multiple ESL mappings.

```
bal eslToBal <ESL file path or directory> <ESL segment definitions path> <output json path or directory>
```

If a directory containing multiple ESL files is given as the input, all ESLs will be converted to Ballerina mappings
and written into the output directory.

## Code generation

Ballerina records can be generated using the EDI mapping file to represent an EDI document. There are two options to
generate records in ballerina.

- **Using ballerina command**

  Ballerina records for the above EDI mapping in edi-mapping1.json can be generated as follows (generated Ballerina
  records will be saved in orderRecords.bal).

```shell
bal codegen edi-mapping1.json orderRecords.bal
```

Generated Ballerina records for the above mapping are shown below.

```
type Header_Type record {|
   string orderId?;
   string organization?;
   string date?;
|};

type Items_Type record {|
   string item?;
   int quantity?;
|};

type SimpleOrder record {|
   Header_Type header;
   Items_Type[] items?;
|};
```

- **Using compiler plugin at the build time**

  The ballerina compiler plugin can be configured to generate EDI records during the build time. This support for ballerina is
  still under development and once it is available, EDI records can be generated using that feature.

## Parsing EDI files

The below code reads the edi-sample1.edi into a json variable named "orderData" and then convert the orderData json to the
generated record "SimpleOrder". Once EDI documents are mapped to the SimpleOrder record, any attribute in the EDI can be
accessed using record's fields as shown in the example code below.

```ballerina
import ballerina/io;
import chathurace/edi.core as edi;

public function main() returns error? {
    edi:EDIMapping mapping = check edi:readMappingFromFile("resources/edi-mapping1.json");

    string ediText = check io:fileReadString("resources/edi-sample1.edi");
    json orderData = check edi:readEDIAsJson(ediText, mapping);
    io:println(orderData.toJsonString());

    SimpleOrder order1 = check orderData.cloneWithType(SimpleOrder);
    io:println(order1.header.date);
}
```

"orderData" json variable value will be as follows (i.e. output of io:println(orderData.toJsonString())):
```json
{
  "header": {
    "orderId": "ORDER_1201",
    "organization": "ABC_Store",
    "date": "2008-01-01"
  },
  "items": [
    {
      "item": "A-250",
      "quantity": 12
    },
    {
      "item": "A-45",
      "quantity": 100
    },
    {
      "item": "D-10",
      "quantity": 58
    },
    {
      "item": "K-80",
      "quantity": 250
    },
    {
      "item": "T-46",
      "quantity": 28
    }
  ]
}
```

A sample Ballerina project which uses the EDI library is given
in [here](https://github.com/chathurace/ballerina-edi/tree/main/samples/simpleEDI)

Also refer to [resources](https://github.com/chathurace/ballerina-edi/tree/main/edi/resources) section for example
mapping files and edi samples.


## Creating an EDI library

Usually, organizations have to work with many EDI formats, and integration developers need to have a convenient way to
work on EDI data with minimum effort. EDI libraries facilitate this by allowing organizations to pack all EDI processing
code for to their EDI collections into an importable library. Therefore, integration developers can simply import those
libraries and convert EDI messages into Ballerina records in a single line of code.

Below command can be used to generate EDI libraries:

```
bal libgen <org name> <library name> <EDI mappings folder> <output folder>
```

The Ballerina library project will be generated in the output folder. This library can be built and published by issuing "
bal pack" and "bal push" commands from the output folder.

Then the generated library can be imported into any Ballerina project and generated utility functions of the library can
be invoked to parse EDI messages into Ballerina records. For example, the below Ballerina code parses an X12 834 EDI
message into the corresponding Ballerina record:

```
m834:Benefit_Enrollment_and_Maintenance b = check hl71:readEDI(ediText, hl71:EDI_834).ensureType();
```



