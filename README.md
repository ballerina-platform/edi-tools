# Ballerina EDI Tools
 
[![Build](https://github.com/ballerina-platform/edi-tools/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/edi-tools/actions/workflows/build-timestamped-master.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/edi-tools.svg)](https://github.com/ballerina-platform/edi-tools/commits/master)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/edi-tools.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module/edi-tools)

## Overview

Electronic Data Interchange (EDI) is a technology designed to facilitate the electronic transfer of business documents among various organizations. The Ballerina EDI tool provides a set of command line tools to work with EDI files in Ballerina.

## Installation

Execute the command below to pull the EDI tool from [Ballerina Central](https://central.ballerina.io/ballerina/edi/latest).

```
$ bal tool pull edi
```

## Usage

The tool supports three main usages as follows.

- **Code generation**: Generate Ballerina records and parser functions for a given EDI schema.
- **Package generation**: Generates Ballerina records, parser functions, utility methods, and a REST connector for a given collection of EDI schemas and organizes those as a Ballerina package.
- **Schema conversion**: Convert various EDI schema formats to Ballerina EDI schema format.

## Define EDI schema

Prior to utilizing the EDI Tools, it is crucial to define the structure of the EDI data meant for import. Developers have the option to utilize the [Ballerina EDI Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) for guidance. This specification outlines the essential components required to describe an EDI schema, encompassing attributes such as name, delimiters, segments, field definitions, components, sub-components, and additional configuration options.

As an illustrative example, consider the following EDI schema definition for a _simple order_, assumed to be stored as `schema.json`:

```json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*", "component": ":", "repetition": "^"},
    "segments" : [
        {
            "code": "HDR",
            "tag" : "header",
            "minOccurances": 1,
            "fields" : [{"tag": "code"}, {"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        {
            "code": "ITM",
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag": "code"}, {"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    ]
}
```

This schema can be employed to parse EDI documents featuring one HDR segment, mapped to the _header_, and any number of ITM segments, mapped to _items_. The HDR segment incorporates three _fields_, corresponding to _orderId_, _organization_, and _date_. Each ITM segment comprises two fields, mapped to _item_ and _quantity_.

Below is an example of an EDI document that can be parsed using the aforementioned schema. Let's assume that the following EDI information is saved in a file named `sample.edi`:

```
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12~
ITM*A-45*100~
ITM*D-10*58~
ITM*K-80*250~
ITM*T-46*28~
```

## Code generation

The below command can be used to generate typed Ballerina records and parser functions for a given EDI schema.

```
bal edi codegen -i <input schema path> -o <output path>
```

The above command generates all Ballerina records and parser functions required for working with data in the given EDI schema and writes those into the file specified in the `output path`. The generated parser function (i.e. `fromEdiString(...)`) can read EDI text files into generated records, which can be accessed from Ballerina code similar to accessing any other Ballerina record. Similarly, the generated serialization function (i.e. `toEdiString(...)`) can serialize generated Ballerina records into EDI text.

### Example

Create a new Ballerina project named `sample` and create a module named `orders` inside that project by using the below commands:

```
$ bal new sample
$ cd sample
$ bal add orders
```

Create a new folder named resources in the root of the project and copy the `schema.json` and `sample.edi` files into it. At this point, the directory structure of the project would look like below:
```
.
├── Ballerina.toml
├── Dependencies.toml
├── main.bal
├── modules
│   └── orders
│       ├── Module.md
│       ├── orders.bal
│       ├── resources
│       └── tests
│           └── lib_test.bal
└── resources
    ├── sample.edi
    └── schema.json
```

Ballerina records for the EDI schema in the `resources/schema.json` can be generated as follows (generated Ballerina records will be saved in `modules/order/records.bal`).

Run the below command from the project root directory to generate the Ballerina parser for the above schema.

```
bal edi codegen -i resources/schema.json -o modules/orders/records.bal
```

Generated Ballerina records for the above schema are shown below:

```ballerina
public type Header_Type record {|
   string code = "HDR";
   string orderId?;
   string organization?;
   string date?;
|};

public type Items_Type record {|
   string code = "ITM";
   string item?;
   int? quantity?;
|};

public type SimpleOrder record {|
   Header_Type header;
   Items_Type[] items = [];
|};
```

### Reading EDI files

The generated ```fromEdiString``` function can be used to read EDI text files into the generated Ballerina record as shown below. Note that any data item in the EDI can be accessed using the record's fields, as shown in the example code.

````ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/sample.edi");
    orders:SimpleOrder sample_order = check orders:fromEdiString(ediText);
    io:println(sample_order.header.date);
}
````

### Writing EDI files

The generated ```toEdiString``` function can be used to serialize ```SimpleOrder``` records into EDI text as shown below:

````ballerina
import ballerina/io;
import sample.orders;
public function main() returns error? {
    orders:SimpleOrder simpleOrder = {header: {code: "HDR", orderId: "ORDER_200", organization: "ABC_Store", date: "17-05-2024"}};
    simpleOrder.items.push({code: "ITM", item: "A680", quantity: 15}); 
    simpleOrder.items.push({code: "ITM", item: "A530", quantity: 2}); 
    simpleOrder.items.push({code: "ITM", item: "A500", quantity: 4});
    string ediText = check orders:toEdiString(simpleOrder);
    io:println(ediText);
}
````

## Package generation

Usually, organizations have to work with many EDI formats, and integration developers need to have a convenient way to work on EDI data with minimum effort. Ballerina EDI libraries facilitate this by allowing organizations to pack all EDI processing codes for their EDI collections into an importable package. Therefore, integration developers can simply import those libraries and convert EDI messages into Ballerina records in a single line of code.

The below command can be used to generate Ballerina records, parser and util functions, and a REST connector for a given collection of EDI schemas organized into a Ballerina package:

```
bal edi libgen -p <organization-name/package-name> -i <input schema folder> -o <output folder>
```

The Ballerina package will be generated in the output folder. This package can be built and published by issuing "bal pack" and "bal push" commands from the output folder. Then the generated package can be imported into any Ballerina project and generated utility functions of the package can be invoked to parse EDI messages into Ballerina records. 

### Example

Let's assume that an organization named "CityMart" needs to work with X12 850, 810, 820, and 855 to handle purchase orders. CityMart's integration developers can put schemas of those X12 specifications into a folder as follows:

````bash
|-- CityMart
    |--lib
    |--schemas
       |--850.json
       |--810.json
       |--820.json
       |--855.json
````

Then the libgen command can be used to generate a Ballerina package as shown below:

````
bal edi libgen -p citymart/porder -i CityMart/schemas -o CityMart/lib
````

The generated Ballerina package will look like below:

````bash
|-- CityMart
    |--lib  
    |--porder
    |     |--modules
    |	  |   |--m850
    |	  |	  |  |--G_850.bal
    |     |   |  |--transformer.bal
    |	  |	  |--m810
    |	  |	  |  |--G_810.bal
    |     |   |  |--transformer.bal
    |	  |	  |--m820
    |	  |	  |  |--G_820.bal
    |     |   |  |--transformer.bal
    |	  |	  |--m855
    |	  |	    |--G_855.bal
    |     |     |--transformer.bal
    |	  |--Ballerina.toml
    |	  |--Module.md
    |	  |--Package.md
    |	  |--porder.bal
    |	  |--rest_connector.bal
    |
    |--schemas
       |--850.json
       |--810.json
       |--820.json
       |--855.json
````

As seen in the above project structure, code for each EDI schema is generated into a separate module, to prevent possible conflicts. Now it is possible to build the above project using the ```bal pack``` command and publish it into the central repository using the ```bal push``` command. Then any Ballerina project can import this package and use it to work with purchase order-related EDI files. An example of using this package for reading an 850 file and writing an 855 file is shown below:

````ballerina
import ballerina/io;
import citymart/porder.m850;
import citymart/porder.m855;

public function main() returns error? {
    string orderText = check io:fileReadString("orders/d15_05_2023/order10.edi");
    m850:Purchase_Order purchaseOrder = check m850:fromEdiString(orderText);
    ...
    m855:Purchase_Order_Acknowledgement orderAck = {...};
    string orderAckText = check m855:toEdiString(orderAck);
    check io:fileWriteString("acks/d15_05_2023/ack10.edi", orderAckText);
}
````

It is quite common for different trading partners to use variations of standard EDI formats. In such cases, it is possible to create partner-specific schemas and generate a partner-specific Ballerina package for processing interactions with the particular partner.

### Using generated EDI libraries as standalone REST services

EDI libraries generated in the previous step can also be compiled to a jar file (using the ```bal build``` command) and executed(using the ```bal run``` command) as a standalone Ballerina service that processes EDI files via a REST interface. This is useful for microservice environments where the EDI processing functionality can be deployed as a separate microservice.

For example, the "citymart" package generated in the above step can be built and executed as a jar file. Once executed, it will expose a REST service to work with X12 850, 810, 820, and 855 files. 

#### Converting of X12 850 EDI text to JSON using the REST service

The below REST call can be used to convert an X12 850 EDI text to JSON using the REST service generated from the "citymart" package:

```
curl --location 'http://localhost:9090/porderParser/edis/850' \
--header 'Content-Type: text/plain' \
--data-raw 'GS*PO*SENDERID*RECEIVERID*20240802*1705*1*X*004010~
ST*850*0001~
BEG*00*NE*4500012345**20240802~
REF*DP*038~
PER*BD*John Doe*TE*1234567890*EM*john.doe@example.com~
FOB*CC~
ITD*01*3*2**30**31~
DTM*002*20240902~
N1*ST*SHIP TO NAME*92*SHIP TO CODE~
N3*123 SHIP TO ADDRESS~
N4*CITY*STATE*12345*US~
PO1*1*10*EA*15.00**BP*123456789012*VP*9876543210*UP*123456789012~
PID*F****PRODUCT DESCRIPTION~
PO4*1*CA*20*LB~
CTT*1~
SE*16*0001~
GE*1*1~
IEA*1*000000001~'
```

The above REST call will return a JSON response like the below:

```
{
    "X12_FunctionalGroup": {
        "FunctionalGroupHeader": {
            "code": "GS",
            "GS01__FunctionalIdentifierCode": "PO",
            "GS02__ApplicationSendersCode": "SENDERID",
            "GS03__ApplicationReceiversCode": "RECEIVERID",
            ... // Other fields
        }
        ... // Other fields
    },
    "InterchangeControlTrailer": {
        "code": "IEA",
        "IEA01__NumberofIncludedFunctionalGroups": 1.0,
        "IEA02__InterchangeControlNumber": 1.0
    }
}
```

#### Converting of JSON to X12 850 EDI text using the REST service

The below REST call can be used to convert a JSON to X12 850 EDI text using the REST service generated from the "citymart" package:

```
curl --location 'http://localhost:9090/ediParser/objects/850' \
--header 'Content-Type: application/json' \
--data-raw '{
    "X12_FunctionalGroup": {
        "FunctionalGroupHeader": {
            "code": "GS",
            "GS01__FunctionalIdentifierCode": "PO",
            "GS02__ApplicationSendersCode": "SENDERID",
            "GS03__ApplicationReceiversCode": "RECEIVERID",
            "GS04__Date": "20240802",
            "GS05__Time": "1705",
            "GS06__GroupControlNumber": 1.0,
            ... // Other fields
        },
        ... // Other fields
    },
    "InterchangeControlTrailer": {
        "code": "IEA",
        "IEA01__NumberofIncludedFunctionalGroups": 1.0,
        "IEA02__InterchangeControlNumber": 1.0
    }
}'
```

The above REST call will return an X12 850 EDI text response like the below:

```
GS*PO*SENDERID*RECEIVERID*20240802*1705*1*X*004010~
ST*850*0001~
BEG*00*NE*4500012345**20240802~
REF*DP*038~
PER*BD*John Doe*TE*1234567890*EM*john.doe@example.com~
FOB*CC~
ITD*01*3*2**30**31~
DTM*002*20240902~
N1*ST*SHIP TO NAME*92*SHIP TO CODE~
N3*123 SHIP TO ADDRESS~
N4*CITY*STATE*12345*US~
PO1*1*10*EA*15.00**BP*123456789012*VP*9876543210*UP*123456789012~
PID*F****PRODUCT DESCRIPTION~
PO4*1*CA*20*LB~
CTT*1~
SE*16*0001~
GE*1*1~
IEA*1*1~
```

## Schema conversion

Instead of writing Ballerina EDI schema from scratch, the Ballerina EDI tool also supports converting various EDI schema formats to Ballerina EDI schema format.

### X12 schema to Ballerina EDI schema

X12, short for ANSI ASC X12, is a standard for electronic data interchange (EDI) in the United States. It defines the structure and format of business documents such as purchase orders, invoices, and shipping notices, allowing for seamless communication between different computer systems. X12 standards cover a wide range of industries, including healthcare, finance, retail, and manufacturing.

The below command can be used to convert the X12 schema to the Ballerina EDI schema:

``` 
bal edi convertX12Schema -H <enable headers mode> -c <enable collection mode > -i <input schema path> -o <output json file/folder path> -d <segment details path>
```

Example:

```
$ bal edi convertX12Schema -i input/schema.xsd -o output/schema.json
```

### EDIFACT schema to Ballerina EDI schema

EDIFACT, which stands for Electronic Data Interchange For Administration, Commerce, and Transport, is an international EDI standard developed by the United Nations. It's widely used in Europe and many other parts of the world. EDIFACT provides a common syntax for exchanging business documents electronically between trading partners, facilitating global trade and improving efficiency in supply chain management.

The below command can be used to convert the EDIFACT schema to the Ballerina EDI schema:

```
bal edi convertEdifactSchema -v <EDIFACT version> -t <EDIFACT message type> -o <output folder>
```

Example:

```
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o output/schema.json
```

### ESL to Ballerina EDI schema

ESL, or Electronic Shelf Labeling, is a technology used in retail stores to display product pricing and information electronically. Instead of traditional paper price tags, ESL systems use digital displays that can be updated remotely, allowing retailers to change prices in real-time and automate pricing strategies.

The below command can be used to convert ESL schema to Ballerina EDI schema:

```
bal edi convertESL -b <segment definitions file path> -i <input ESL schema file/folder> -o <output file/folder>
```

Example:

```
$ bal edi convertESL -b segment_definitions.yaml -i esl_schema.esl -o output/schema.json
```

## Issues and projects

The **Issues** and **Projects** tabs are disabled for this repository as this is part of the Ballerina library. To report bugs, request new features, start new discussions, view project boards, etc., visit the Ballerina library [parent repository](https://github.com/ballerina-platform/ballerina-library).

This repository only contains the source code for the package.

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

   * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
   * [OpenJDK](https://adoptium.net/)

    > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

    > **Note**: Ensure that the Docker daemon is running before executing any tests.

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```
 > **Note**: The content of the `.ballerina/.config/bal-tools.toml` file will be wiped out during the build process.

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [EDI Tool documentation](https://ballerina.io/learn/edi-tool/).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
