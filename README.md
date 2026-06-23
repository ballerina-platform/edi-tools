# Ballerina EDI Tools

[![Build](https://github.com/ballerina-platform/edi-tools/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/edi-tools/actions/workflows/build-timestamped-master.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/edi-tools.svg)](https://github.com/ballerina-platform/edi-tools/commits/master)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/edi-tools.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module/edi-tools)

## Overview

Electronic Data Interchange (EDI) is how businesses exchange documents such as purchase orders, invoices, and shipping notices with their trading partners. Most EDI traffic follows one of two standards:

- **EDIFACT** — the international UN standard, with message types such as `ORDERS`, `INVOIC`, and `DESADV`.
- **X12** — the ANSI ASC X12 standard used across North America, with transaction sets such as `850` (purchase order), `810` (invoice), and `856` (ship notice).

You do not need to learn the raw EDI wire format. Point the `bal edi` tool at the standard you already work with, and it generates the Ballerina record types and parser functions for you — so a purchase order or invoice becomes an ordinary typed record you read and write like any other Ballerina value.

The tool can:

- **Generate code from an EDIFACT or X12 spec** — the common case, covered first below.
- **Bundle several schemas into a reusable library package**, optionally exposed as a REST service.
- **Generate code from a custom schema** — for proprietary or non-standard formats.

The generated code uses the [`ballerina/edi`](https://github.com/ballerina-platform/module-ballerina-edi) module at runtime.

## Installation

Pull the EDI tool from [Ballerina Central](https://central.ballerina.io/):

```
$ bal tool pull edi
```

## Generate from an EDIFACT spec

EDIFACT is the international EDI standard. The tool already knows the EDIFACT message specifications, so there is no schema to write — you just name the version and message type.

**Step 1 — Convert the spec into a Ballerina EDI schema.** Use `-v` for the EDIFACT version (e.g. `d03a`) and `-t` for the message type (e.g. `ORDERS`, `INVOIC`):

```
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o resources/orders-schema.json
```

**Step 2 — Generate Ballerina records and parser functions:**

```
$ bal edi codegen -i resources/orders-schema.json -o modules/orders/orders.bal
```

`modules/orders` now contains typed records plus `fromEdiString` / `toEdiString`. Because EDIFACT documents carry an envelope, the tool also emits `interchangeFromEdiString` / `interchangeToEdiString`. See [Using the generated code](#using-the-generated-code).

> **Tip:** For common EDIFACT D03A message types, prebuilt packages are published under the `ballerinax` organization (e.g. `ballerinax/edifact.d03a.supplychain`) — you can import those directly without generating anything. See the [`ballerina/edi` module](https://github.com/ballerina-platform/module-ballerina-edi#working-with-standard-edi-formats).

## Generate from an X12 schema

X12 is the EDI standard used across North America. X12 specifications are licensed from ASC X12, so you start from the X12 schema (XSD) you are entitled to use and convert it.

**Step 1 — Convert the X12 schema into a Ballerina EDI schema:**

```
$ bal edi convertX12Schema -i input/850.xsd -o resources/850-schema.json
```

**Step 2 — Generate Ballerina code:**

```
$ bal edi codegen -i resources/850-schema.json -o modules/po/po.bal
```

The result is the same shape as the EDIFACT flow: typed records and parser functions you can use right away.

## Using the generated code

Set up a project and a module to hold the generated code, then run `codegen` into it:

```
$ bal new sample
$ cd sample
$ bal add orders
$ bal edi codegen -i resources/orders-schema.json -o modules/orders/orders.bal
```

The generated module exposes typed records named after the schema, plus parser functions. For an `ORDERS` schema, the body record is `ORDERS` and the interchange wrapper is `ORDERSInterchange`.

### Reading EDI files

`fromEdiString` reads EDI text into a typed record. Any value in the EDI can then be accessed through the record's fields:

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/order.edi");
    orders:ORDERS document = check orders:fromEdiString(ediText);
    io:println(document);
}
```

### Writing EDI files

`toEdiString` serializes a typed record back into EDI text:

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    orders:ORDERS document = { /* populate the record */ };
    string ediText = check orders:toEdiString(document);
    io:println(ediText);
}
```

### Reading and writing EDI envelopes

A real EDI file is wrapped in an **envelope** — interchange and (for X12) functional-group headers and trailers around one or more transactions. When the schema comes from an X12 or EDIFACT spec, `codegen` also emits typed envelope wrappers and envelope-aware functions:

- `<Name>Interchange`, `<Name>FunctionalGroup` (X12), and `<Name>Transaction` records that mirror the envelope hierarchy. Each `<Name>Transaction.body` is `<Name>|error`, so a malformed transaction body is captured rather than aborting the whole parse (fail-safe).
- `headersFromEdiString` — extracts just the envelope headers (useful for routing).
- `interchangeFromEdiString` — parses the full interchange into a typed `<Name>Interchange`.
- `interchangeToEdiString` — the inverse, serializing a `<Name>Interchange` back to EDI text.

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/order.edi");

    // Parse the full envelope hierarchy into typed records.
    orders:ORDERSInterchange interchange = check orders:interchangeFromEdiString(ediText);
    foreach var txn in interchange.transactions {
        if txn.body is error {
            io:println("Quarantined: ", (<error>txn.body).message());
            continue;
        }
        io:println(txn.body);
    }

    // Serialize a (filtered/transformed) interchange back to EDI text.
    string ediOut = check orders:interchangeToEdiString(interchange);
    io:println(ediOut);
}
```

> The envelope wrappers require `ballerina/edi >= 1.6.0`. For envelope-aware schemas, `libgen` pins this floor via a `[[dependency]]` block in the generated package's `Ballerina.toml` and prints a notice.

## Generating a library package

Organizations usually work with several EDI formats at once. Instead of running `codegen` per schema and tracking the outputs by hand, `libgen` bundles a directory of schemas into a single importable Ballerina package:

```
bal edi libgen -p <organization-name/package-name> -i <input schema folder> -o <output folder>
```

For example, an organization "CityMart" that handles X12 `850`, `810`, `820`, and `855` can drop those schemas into a folder and run:

```
bal edi libgen -p citymart/porder -i CityMart/schemas -o CityMart/lib
```

Each schema is generated into its own module (`m850`, `m810`, …) to avoid conflicts, alongside a `Ballerina.toml`, shared utilities, and a REST connector. Build and publish the package with `bal pack` and `bal push`, then import it like any other library:

```ballerina
import ballerina/io;
import citymart/porder.m850;
import citymart/porder.m855;

public function main() returns error? {
    string orderText = check io:fileReadString("orders/order10.edi");
    m850:Purchase_Order purchaseOrder = check m850:fromEdiString(orderText);
    // ...
    m855:Purchase_Order_Acknowledgement orderAck = { /* ... */ };
    string ackText = check m855:toEdiString(orderAck);
    check io:fileWriteString("acks/ack10.edi", ackText);
}
```

Because trading partners often use variations of a standard format, you can also generate a partner-specific package from partner-specific schemas.

### Running a generated package as a REST service

A generated package also includes a REST connector, so it can be built (`bal build`) and run (`bal run`) as a standalone service that converts EDI over HTTP — handy when EDI processing should be its own microservice. Each schema gets an EDI-to-JSON and a JSON-to-EDI endpoint. For example, converting an X12 850 to JSON:

```
curl --location 'http://localhost:9090/porderParser/edis/850' \
--header 'Content-Type: text/plain' \
--data-raw 'ST*850*0001~
BEG*00*NE*4500012345**20240802~
PO1*1*10*EA*15.00**BP*123456789012~
CTT*1~
SE*16*0001~'
```

The matching `objects/850` endpoint performs the reverse (JSON to X12 850 text).

## Custom EDI schemas

If you work with a proprietary or non-standard format that is neither X12 nor EDIFACT, describe its structure directly in the Ballerina EDI schema format (JSON) and run `codegen` on it — no conversion step needed. A minimal schema for a simple order looks like:

```json
{
    "name": "SimpleOrder",
    "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
    "segments": [
        {
            "code": "HDR",
            "tag": "header",
            "minOccurances": 1,
            "fields": [{"tag": "code"}, {"tag": "orderId"}, {"tag": "organization"}, {"tag": "date"}]
        },
        {
            "code": "ITM",
            "tag": "items",
            "maxOccurances": -1,
            "fields": [{"tag": "code"}, {"tag": "item"}, {"tag": "quantity", "dataType": "int"}]
        }
    ]
}
```

This parses EDI documents with one `HDR` segment (mapped to `header`) and any number of `ITM` segments (mapped to `items`), for example:

```
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12~
ITM*A-45*100~
```

Generate code from it the same way:

```
bal edi codegen -i schema.json -o modules/orders/orders.bal
```

For the full schema grammar — delimiters, segment groups, fields, components, sub-components, the `envelope` declaration, and additional configuration — see the [Ballerina EDI Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md).

### ESL schemas

ESL (Electronic Shelf Labeling) schemas, used for retail pricing feeds, can be converted with `convertESL`, supplying the base segment definitions:

```
$ bal edi convertESL -b segment_definitions.yaml -i esl_schema.esl -o resources/schema.json
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

2. Download and install [Docker](https://www.docker.com/get-started).

    > **Note**: Ensure that the Docker daemon is running before executing any tests.

3. Export your GitHub personal access token with the `read:packages` scope and your GitHub username. The build downloads the jBallerina tools distribution and the timestamped `ballerina/edi` snapshots from [GitHub Packages](https://github.com/orgs/ballerina-platform/packages), so a system-wide Ballerina installation is not required.

   ```bash
   export packageUser=<GitHub username>
   export packagePAT=<GitHub personal access token with read:packages scope>
   ```

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
