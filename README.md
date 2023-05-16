## Module Overview

EDI tools provide the below set of command line tools to work with EDI files in Ballerina.

- **Code generation**: Generate Ballerina records and parsing functions for a given EDI schema
- **Library generation**: Generates Ballerina records, parsing functions, utility methods and a REST connector for a given collection of EDI schemas and organize those as a Ballerina library

## Compatibility

|                                   | Version               |
|:---------------------------------:|:---------------------:|
| Ballerina Language                | 2201.5.0              |
| Java Development Kit (JDK)        | 11                    |

## Code generation

Usage:
```
bal edi codegen <EDI schema path> <output path>
```
Above command generates all Ballerina records and parsing functions required for working with data in the given EDI schema and writes those in to the file specified in "output path". Generated parsing function (i.e. fromEdiString(...)) can read EDI text files into generated records, which can be accessed from Ballerina code similar to accessing any other Ballerina record. Similarly, generated serialization function (i.e. toEdiString(...)) can serialize Generated Ballerina records into EDI text.

### Example

A simple EDI schema is shown below (let's assume that this is saved in edi-schema.json file):

````json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*"},
    "segments" : {
        "HDR": {
            "tag" : "header",
            "fields" : [{"tag" : "code"}, {"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        "ITM": {
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag" : "code"}, {"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    }
}
````

Above schema can be used to parse EDI documents with one HDR segment (mapped to "header") and any number of ITM segments (mapped to "items"). HDR segment contains three fields, which are mapped to "orderId", "organization" and "date". Each ITM segment contains two fields mapped to "item" and "quantity". Below is a sample EDI document that can be parsed using the above schema (let's assume that below EDI is saved in edi-sample1.edi file):

````edi
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12
ITM*A-45*100
ITM*D-10*58
ITM*K-80*250
ITM*T-46*28
````

Ballerina records for the EDI schema in edi-schema.json can be generated as follows (generated Ballerina records will be saved in orderRecords.bal):

```
java -jar editools.jar codegen resources/edi-schema1.json modules/hmartOrder/orderRecords.bal
```

Generated Ballerina records for the above schema are shown below:

```ballerina
type Header_Type record {|
   string code?;
   string orderId?;
   string organization?;
   string date?;
|};

type Items_Type record {|
   string code?;
   string item?;
   int quantity?;
|};

type SimpleOrder record {|
   Header_Type header;
   Items_Type[] items?;
|};
```

### Reading EDI files

Generated ```fromEdiString``` function can be used to read EDI text files into the generated Ballerina record as shown below. Note that any data item in the EDI can be accessed using record's fields as shown in the example code.

````ballerina
import ballerina/io;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/edi-sample1.edi");
    SimpleOrder order1 = check hmartOrder:fromEdiString(ediText);
    io:println(order1.header.date);
}
````

### Writing EDI files

Generated ```toEdiString``` function can be used to serialize ```SimpleOrder`` records into EDI text as shown below:

````ballerina
import ballerina/io;

public function main() returns error? {
    SimpleOrder order2 = {...};
    string orderEDI = check hmartOrder:toEdiString(order2);
    io:println(orderEDI);
}
````

## Creating an EDI library

Usually, organizations have to work with many EDI formats, and integration developers need to have a convenient way to work on EDI data with minimum effort. Ballerina EDI libraries facilitate this by allowing organizations to pack all EDI processing code for to thier EDI collections in to an importable library. Therefore, integration developers can simply import those libraries and convert EDI messages into Ballerin records in a single line of code.

Below command can be used to generate EDI libraries:

```
java -jar editools.jar libgen <org name> <library name> <EDI mappings folder> <output folder>
```

Ballerina library project will be generated in the output folder. This library can be built and published by issuing "bal pack" and "bal push" commands from the output folder. Then the generated library can be imported into any Ballerina project and generated utility functions of the library can be invoked to parse EDI messages into Ballerin records. 

For example, let's assume that an organization named "CityMart" needs to work with X12 850, 810, 820 and 855 for handling purchase orders. CityMart's integration developers can put schemas of those X12 specifications into a folder as follows:
````bash
|-- CityMart
    |--lib
    |--schemas
	   |--850.json
	   |--810.json
	   |--820.json
	   |--855.json
````
Then the libgen command can be used to generate a Ballerina library as shown below:
````
java -jar editools.jar libgen citymart porder CityMart/schemas CityMart/lib
````
The generated Ballerina library will look like below:
````bash
|-- CityMart
    |--lib
	|  |--porder
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
As seen in the above project structure, code for each EDI schema is generated into a separate module, in order to prevent possible conflicts. Now it is possible to build the above project using the ```bal pack``` command and publish it into the central repository using the ```bal push``` command. Then any Ballerina project can import this package and use it to work with purchase order related EDI files. An example of using this library for reading a 850 file and writing a 855 file is shown below:

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
It is quite common for different trading partners to use variations of standard EDI formats. In such case, it is possible to create partner specific schemas and generate a partner specific Ballerina library for processing interactions with the particular partner.

### Using generated EDI libraries as standalone REST services

EDI libraries generated in the previous step can also be compiled to a jar file (using the ```bal build``` command) and executed as a standalone Ballerina service that processes EDI files via a REST interface. This is useful for micro services environments where the EDI processing functionality can be deployed as a separate micro service.

For example, "citymart" library generated in the above step can be built and executed as a jar file. Once executed, it will expose a REST service to work with X12 850, 810, 820 and 855 files. Converting of X12 850 EDI text to JSON using the REST service is shown below:

```
curl --request POST \
  --url http://localhost:9090/porderParser/edis/850 \
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


