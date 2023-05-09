// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

# Record for representing EDI schema.
#
# + name - Name of the schema. This will be used as the main record name by the code generation tool.  
#
# + tag - Tag for the root element. Can be same as the name.  
#
# + delimiters - Delimiters used to separate EDI segments, fields, components, etc.  
#
# + ignoreSegments - List of segment schemas to be ignored when matching a EDI text. 
# For example, if it is necessary to process X12 transaction sets only, without ISA as GS segments,
# and if the schema contains ISA and GS segments as well, ISA and GS can be provided as ignoreSegments.
#
# + preserveEmptyFields - Indicates how to process EDI fields, components and subcomponents containing empty values.
# true: Includes fields, components and subcomponents with empty values in the generated JSON.
# String values will be represented as empty strings. 
# Multi-value fields (i.e. repeats) will be represented as empty arrays.
# All other types will be represented as null.
# false: Omits fields, components and subcomponents with empty values.
# 
# + includeSegmentCode - Indicates whether or not to include the segment code as a field in output JSON values.
#
# + segments - Array of segment and segment group schemas
public type EDISchema record {|
    string name;
    string tag = "Root_mapping";

    record {|
        string segment;
        string 'field;
        string component;
        string subcomponent = "NOT_USED";
        string repetition = "NOT_USED";
        string decimalSeparator?;
    |} delimiters;

    string[] ignoreSegments = [];

    boolean preserveEmptyFields = true;
    boolean includeSegmentCode = true;

    EDIUnitSchema[] segments = [];
|};

public type EDIUnitSchema EDISegSchema|EDISegGroupSchema;

public type EDISegGroupSchema record {|
    string tag;
    int minOccurances = 0;
    int maxOccurances = 1;
    EDIUnitSchema[] segments = [];
|};

public type EDISegSchema record {|
    string code;
    string tag;
    boolean truncatable = true;
    int minOccurances = 0;
    int maxOccurances = 1;
    EDIFieldSchema[] fields = [];
|};

public type EDIFieldSchema record {|
    string tag;
    boolean repeat = false;
    boolean required = false;
    boolean truncatable = true;
    EDIDataType dataType = STRING;
    int startIndex = -1;
    int length = -1;
    EDIComponentSchema[] components = [];
|};

public type EDIComponentSchema record {|
    string tag;
    boolean required = false;
    boolean truncatable = true;
    EDIDataType dataType = STRING;
    EDISubcomponentSchema[] subcomponents = [];
|};

public type EDISubcomponentSchema record {|
    string tag;
    boolean required = false;
    EDIDataType dataType = STRING;
|};
