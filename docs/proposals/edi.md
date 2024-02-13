# Proposal: EDI

_Authors_: @chathurace @ruks  
_Reviewers_:     
_Created_: 2023/03/31  
_Updated_:   
_Issue_: [#495](https://github.com/ballerina-platform/ballerina-extended-library/issues/495)

## Summary

Having EDI file processing capabilities is essential to enable EDI integrations. This library provides the functionalities
to parse EDI files and write additional logic on those data.

## Module overview

The `edi` package provides the functionality to read EDI files and map those to Ballerina records or the 'json' type. Mappings for EDI
files have to be provided in JSON format. Once a mapping is provided, the EDI module can generate Ballerina records to hold
data in any EDI file represented by that mapping. Then, the module can read EDI files (in text format) and convert them into generated
Ballerina records or JSON values, which can be accessed from Ballerina code.

## EDI file structure

The below is a sample of a simple EDI file.

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

An EDI mapping file is required in order to parse an EDI document to Ballerina-readable code. The mapping file can be
implemented manually for a given EDI document or can be converted from an existing definition like `Smooks`
or `ESL`.

The below is a sample EDI mapping file (i.e., `simple-order-mapping.json`) for the above EDI document.

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

The above mapping can be used to parse EDI documents with one HDR segment (mapped to `header`) and any number of ITM
segments (mapped to `items`). The HDR segment contains three fields, which are mapped to `orderId`, `organization`, and `
date`. Each ITM segment contains two fields mapped to `item` and `quantity`. The below is a sample EDI document that can be
parsed using the above mapping (assuming that the EDI below is saved in the `edi-sample1.edi` file).

## Converting Smooks mapping files to Ballerina mappings

Smooks library is commonly used for parsing EDI files. Therefore, many organizations have already created Smooks
mappings for their EDIs. The Ballerina `edi` module can convert such Smooks mappings to Ballerina-compatible mappings so that
organizations can start using Ballerina for EDI processing without redoing any mappings.

The command below converts a Smooks EDI mapping to a Ballerina EDI mapping.

```bash
$ bal edi smooksToBal <Smooks mapping xml file path> <Ballerina mapping json file path>
```

For example, the command below converts the Smooks mapping for
EDIFACT [Invoice EDI](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.xml) to a
Ballerina-compatible JSON mapping.

```bash
$ bal edi smooksToBal d3a-invoic-1/mapping.xml d3a-invoic-1/mapping.json
```

A [`mapping.json` file](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.json) will be generated.

You can use the generated JSON mapping to generate Ballerina records and parse invoice EDIs as shown above.

## Convert EDI Schema Language (ESL) files to Ballerina-compatible mappings

ESL is another format used in EDI mapping files. The Ballerina EDI tool can convert ESL mappings into Ballerina-compatible
mappings so that it is possible to generate Ballerina code and process EDIs defined in ESLs without having to rework on the
mappings.

> The following command converts ESL files to Ballerina EDI mappings. Note that segment definitions are given in a separate
> file, which is usually shared by multiple ESL mappings.

```bash
$ bal edi eslToBal <ESL file path or directory> <ESL segment definitions path> <output json path or directory>
```

If a directory containing multiple ESL files is given as the input, all ESLs will be converted to Ballerina mappings
and written into the output directory.

## Code generation

Ballerina records can be generated using the EDI mapping file to represent an EDI document. There are two options to
generate records in ballerina.

### Using a Ballerina command

Ballerina records for the above EDI mapping in the `simple-order-mapping.json` file can be generated as follows (generated Ballerina
records will be saved in the `orderRecords.bal` file).

```bash
$ bal edi gen simple-order-mapping.json orderRecords.bal
```

The generated Ballerina records for the above mapping are shown below.

```ballerina
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

### Using compiler plugin at the build time

> The Ballerina compiler plugin can be configured to generate EDI records during the build time. This support for Ballerina is
> still under development and once it is available, EDI records can be generated using that feature.

## Parsing EDI files

The code below reads the `edi-sample1.edi` into a JSON variable named `orderData` and then converts the `orderData` JSON to the
generated `SimpleOrder` record. Once EDI documents are mapped to the `SimpleOrder` record, any attribute in the EDI can be
accessed using the fields of the record as shown in the example code below.

```ballerina
import ballerina/io;
import chathurace/edi.core as edi;

public function main() returns error? {
    edi:EDIMapping mapping = check edi:readMappingFromFile("resources/simple-order-mapping.json");

    string ediText = check io:fileReadString("resources/edi-sample1.edi");
    json orderData = check edi:readEDIAsJson(ediText, mapping);
    io:println(orderData.toJsonString());

    SimpleOrder order1 = check orderData.cloneWithType(SimpleOrder);
    io:println(order1.header.date);
}
```

The `orderData` JSON variable value will be as follows (i.e., the output of `io:println(orderData.toJsonString())`).
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

This [sample Ballerina project](https://github.com/chathurace/ballerina-edi/tree/main/samples/simpleEDI) uses the EDI library.

Also, for example mapping files and EDI samples, see [resources](https://github.com/chathurace/ballerina-edi/tree/main/edi/resources).


## Creating an EDI library

Usually, organizations have to work with many EDI formats and integration developers need to have a convenient way to
work on EDI data with minimum effort. The EDI libraries facilitate this by allowing organizations to pack all EDI-processing
code for converting their EDI collections into importable libraries. Therefore, integration developers can simply import those
libraries and convert EDI messages into Ballerina records via a single line of code.

The command below can be used to generate EDI libraries.

```bash
$ bal edi lib <org name> <library name> <EDI mappings folder> <output folder>
```

The Ballerina library project will be generated in the output folder. This library can be built and published by
issuing the `bal pack` and `bal push` commands from the output folder. However, once the support for `generated` directories is provided,
it should be able to import the generated code to the user code.

Then, the generated library can be imported into any Ballerina project, and the generated utility functions of the library can
be invoked to parse EDI messages into Ballerina records. For example, the Ballerina code below parses an `X12 834` EDI
message into the corresponding Ballerina record.

```ballerina
m834:Benefit_Enrollment_and_Maintenance b = check hl71:readEDI(ediText, hl71:EDI_834).ensureType();
```
