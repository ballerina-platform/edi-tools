## Module Overview

EDI module provides functionality to read EDI files and map those to Ballerina records or 'json' type. Mappings for EDI files have to be provided in json format. Once a mapping is provided, EDI module can generate Ballerina records to hold data in any EDI file represented by that mapping. Then the module can read EDI files (in text format) in to generated Ballerina records or as json values, which can be accessed from Ballerina code.

## Compatibility

|                                   | Version               |
|:---------------------------------:|:---------------------:|
| Ballerina Language                | 2201.4.1              |
| Java Development Kit (JDK)        | 11                    |

## Example

A simple EDI mapping is shown below (let's assume that this is saved in edi-mapping1.json file):

````json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*"},
    "segments" : {
        "HDR": {
            "tag" : "header",
            "fields" : [{"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        "ITM": {
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    }
}
````

Above mapping can be used to parse EDI documents with one HDR segment (mapped to "header") and any number of ITM segments (mapped to "items"). HDR segment contains three fields, which are mapped to "orderId", "organization" and "date". Each ITM segment contains two fields mapped to "item" and "quantity". Below is a sample EDI document that can be parsed using the above mapping (let's assume that below EDI is saved in edi-sample1.edi file):

````edi
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12
ITM*A-45*100
ITM*D-10*58
ITM*K-80*250
ITM*T-46*28
````

### Code generation

Ballerina records for the above the EDI mapping in edi-mapping1.json can be generated as follows (generated Ballerina records will be saved in orderRecords.bal):

```
java -jar edi.jar codegen edi-schema1.json orderRecords.bal
```

Generated Ballerina records for the above mapping are shown below:

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

### Reading EDI files

Below code reads the edi-sample1.edi into a json variable named "orderData" and then convert the orderData json to the generated record "SimpleOrder". Once EDI documents are mapped to the SimpleOrder record, any attribute in the EDI can be accessed using record's fields as shown in the example code below.

````ballerina
import ballerina/io;
import balarinax/edi;

public function main() returns error? {
    EDIReader ediReader = check new(check io:fileReadJson("resources/edi-schema1.json"));
    string ediText = check io:fileReadString("resources/edi-sample1.edi");
    json orderData = check ediReader.readEDI(ediText);
    io:println(orderData.toJsonString());

    SimpleOrder order1 = check orderData.cloneWithType(SimpleOrder);
    io:println(order1.header.date);
}
````
"orderData" json variable value will be as follows (i.e. output of io:println(orderData.toJsonString())):

````json
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
````

### Writing EDI files

Ballerina EDI module can also convert Ballerina records or JSON data into EDI texts, based on a given schema. Below code demonstrates the conversion of a SimpleOrder record in a EDI text based on the schema used in the above example:

````ballerina
import ballerina/io;
import balarinax/edi;

public function main() returns error? {
    SimpleOrder order2 = {...};
    EDIWriter ediWriter = check new(check io:fileReadJson("resources/edi-schema1.json"));
    string orderEDI = check ediWriter.writeEDI(order2.toJson());
    io:println(orderEDI);
}
````

A sample Ballerina project which uses the EDI library is given in [here](https://github.com/chathurace/ballerina-edi/tree/main/samples/simpleEDI)

Also refer to [resources](https://github.com/chathurace/ballerina-edi/tree/main/edi/resources) section for example mapping files and edi samples.

## Converting Smooks mapping files to Ballerina mappings

Smooks library is commonly used for parsing EDI files. Therefore, many organizations have already created Smooks mappings for their EDIs. Ballerina EDI module can convert such Smooks mapping to Ballerina compatible mappings, so that organizations can start using Ballerina for EDI processing without redoing any mappings.

Following command converts Smooks EDI mapping to Ballerina EDI mapping:

```
java -jar edi.jar smooksToBal <Smooks mapping xml file path> <Ballerina mapping json file path>
```

For example, the below command converts the Smooks mapping for EDIFACT [Invoice EDI](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.xml) to a Ballerina compatible json mapping:

```
java -jar edi.jar smooksToBal d3a-invoic-1/mapping.xml d3a-invoic-1/mapping.json
```

Generated json mapping is shown [here](https://github.com/chathurace/ballerina-edi/blob/main/edi/resources/d3a-invoic-1/mapping.json).

Then we can use the generated json mapping to generate Ballerina records and to parse invoice EDIs as shown above.

## Converting EDI Schema Language (ESL) files to Ballerina compatible mappings

ESL is another format used in EDI mapping files. Ballerina EDI tool can convert ESL mappings into Ballerina compatible mappings, so that it is possible to generate Ballerina code and process EDIs defined in ESLs without having to rework on mappings.

Following command converts ESL files to Ballerina EDI mappings. Note that segment definitions are given in a separate file, which is usually shared by multiple ESL mappings.

```
java -jar edi.jar eslToBal <ESL file path or directory> <ESL segment definitions path> <output json path or directory>
```

If a directory containing multiple ESL files are given as the input, all ESLs will be converted to Ballerina mappings and written into the output directory.

## Creating an EDI library

Usually, organizations have to work with many EDI formats, and integration developers need to have a convenient way to work on EDI data with minimum effort. EDI libraries facilitate this by allowing organizations to pack all EDI processing code for to thier EDI collections in to an importable library. Therefore, integration developers can simply import those libraries and convert EDI messages into Ballerin records in a single line of code.

Below command can be used to generate EDI libraries:

```
java -jar edi.jar libgen <org name> <library name> <EDI mappings folder> <output folder>
```

Ballerina library project will be generated in the output folder. This library can be built and published by issuing "bal pack" and "bal push" commands from the output folder.

Then the generated library can be imported into any Ballerina project and generated utility functions of the library can be invoked to parse EDI messages into Ballerin records. For example, the below Ballerina code parses an X12 834 EDI message into the corresponding Ballerina record:

```
m834:Benefit_Enrollment_and_Maintenance b = check hl71:readEDI(ediText, hl71:EDI_834).ensureType();
```

## Using generated EDI libraries as standalone REST services

EDI libraries generated in the previous step can also be compiled to a jar file and executed as a standalone Ballerina service that processes EDI files via a REST interface. This is useful for micro services development environments where the EDI processing functionality can be deployed as a separate micro service.

For example, if a library named "citymart" is generated with some X12 EDI schemas including 834, EDI 834 text messages can be converted to JSON as follows:

```
curl --request POST \
  --url http://localhost:9090/citymartEDIParser/834 \
  --header 'Content-Type: text/plain' \
  --data 'ST*834*12345*005010X220A1~
BGN*00*12456*20020601*1200****~
REF*38*ABCD012354~
AMT*cc payment*467.34*~
N1*P5**FI*999888777~
N1*IN**FI*654456654~
INS*Y*18*025**A***FT~
REF*0F*202443307~
REF*1L*123456001~
NM1*IL*1*SMITH*WILLIAM****ZZ*202443307~
HD*025**DEN~
DTP*348*D8*20020701~
SE*12*12345~'
```

Above REST call will return a JSON response as below:

```
{
	"Transaction_Set_Header": {
		"Transaction_Set_Identifier_Code": "834",
		"Transaction_Set_Control_Number": "12345",
		"Implementation_Convention_Reference": "005010X220A1"
	},
	"Beginning_Segment": {
		"Transaction_Set_Purpose_Code": "00",
		"Reference_Identification": "12456",
		"Date": "20020601",
		"Time": "1200"
	},
	"Reference_Information": [
		{
			"Reference_Identification_Qualifier": "38",
			"Reference_Identification": "ABCD012354"
		}
	],
	"Date_or_Time_or_Period": [],
	"Monetary_Amount_Information": [
		{
			"Amount_Qualifier_Code": "cc payment",
			"Monetary_Amount": 467.34
		}
	],
	"Quantity_Information": [],
	"A_1000_Loop": [
		{
			"Party_Identification": {
				"Entity_Identifier_Code": "P5",
				"Identification_Code_Qualifier": "FI",
				"Identification_Code": "999888777"
			},
			"Additional_Name_Information": [],
			"Party_Location": [],
			"Administrative_Communications_Contact": [],
			"A_1100_Loop": []
		},
		{
			"Party_Identification": {
				"Entity_Identifier_Code": "IN",
				"Identification_Code_Qualifier": "FI",
				"Identification_Code": "654456654"
			},
			"Additional_Name_Information": [],
			"Party_Location": [],
			"Administrative_Communications_Contact": [],
			"A_1100_Loop": []
		}
	],
	"A_2000_Loop": [
		{
			"Insured_Benefit": {
				"Yes_No_Condition_or_Response_Code": "Y",
				"Individual_Relationship_Code": "18",
				"Maintenance_Type_Code": "025",
				"Benefit_Status_Code": "A",
				"Employment_Status_Code": "FT"
			},
			"Reference_Information_2": [
				{
					"Reference_Identification_Qualifier": "0F",
					"Reference_Identification": "202443307"
				},
				{
					"Reference_Identification_Qualifier": "1L",
					"Reference_Identification": "123456001"
				}
			],
			"Date_or_Time_or_Period_2": [],
			"A_2100_Loop": [
				{
					"Individual_or_Organizational_Name": {
						"Entity_Identifier_Code": "IL",
						"Entity_Type_Qualifier": "1",
						"Name_Last_or_Organization_Name": "SMITH",
						"Name_First": "WILLIAM",
						"Identification_Code_Qualifier": "ZZ",
						"Identification_Code": "202443307"
					},
					"Employment_Class": [],
					"Monetary_Amount_Information_2": [],
					"Health_Care_Information_Codes": [],
					"Language_Use": []
				}
			],
			"A_2200_Loop": [],
			"A_2300_Loop": [
				{
					"Health_Coverage": {
						"Maintenance_Type_Code": "025",
						"Insurance_Line_Code": "DEN"
					},
					"Date_or_Time_or_Period_4": [
						{
							"Date_Time_Qualifier": "348",
							"Date_Time_Period_Format_Qualifier": "D8",
							"Date_Time_Period": "20020701"
						}
					],
					"Monetary_Amount_Information_3": [],
					"Reference_Information_3": [],
					"Identification_Card": [],
					"A_2310_Loop": [],
					"A_2320_Loop": []
				}
			],
			"A_2400_Loop": [],
			"A_2500_Loop": [],
			"A_2600_Loop": []
		}
	],
	"Transaction_Set_Trailer": {
		"Number_of_Included_Segments": 12,
		"Transaction_Set_Control_Number": "12345"
	}
}
```


