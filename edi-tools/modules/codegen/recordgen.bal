// Copyright (c) 2024 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/io;
import ballerina/log;
import ballerina/edi;

map<BalType> ediToBalTypes = {
    "string": BSTRING,
    "int": BINT,
    "float": BFLOAT
};

type GenContext record {|
    map<BalRecord> typeRecords = {};
    map<int> typeNumber = {};
|};

# Generates all Ballerina records required to represent EDI data in the given schema and writes those to a file.
#
# + mapping - EDI schema for which records need to be generated
# + outpath - Path of the file to write generated records. This should be a .bal file.
# + return - Returns error if the record generation is not successfull
public function generateCodeToFile(edi:EdiSchema mapping, string outpath) returns error? {
    BalRecord[] records = check generateCode(mapping);
    string sRecords = "";
    foreach BalRecord rec in records {
        sRecords += rec.toString() + "\n";
    }
    _ = check io:fileWriteString(outpath, sRecords);
}

# Generates all Ballerina records required to represent EDI data in the given schema.
#
# + mapping - EDI schema for which records need to be generated
# + return - Returns an array of generated records. Error if the generation is not successfull.
public function generateCode(edi:EdiSchema mapping) returns BalRecord[]|error {
    GenContext context = {};
    _ = check generateRecordForUnits(mapping.segments, mapping.name, context);
    return context.typeRecords.toArray();
}

function generateRecordForSegmentGroup(edi:EdiSegGroupSchema groupmap, GenContext context) returns BalRecord|error {
    string sgTypeName = generateTypeName(groupmap.tag, context);
    return check generateRecordForUnits(groupmap.segments, sgTypeName, context);
}

function generateRecordForUnits(edi:EdiUnitSchema[] umaps, string typeName, GenContext context) returns BalRecord|error {
    BalRecord sgrec = new (typeName);
    foreach edi:EdiUnitSchema umap in umaps {
        if umap is edi:EdiUnitRef {
            return error("Segment reference is not supported for this operation.");
        }
        if umap is edi:EdiSegSchema {
            BalRecord srec = check generateRecordForSegment(umap, context);
            sgrec.addField(srec, umap.tag, umap.maxOccurances != 1, umap.minOccurances == 0);
        } else {
            BalRecord srec = check generateRecordForSegmentGroup(umap, context);
            sgrec.addField(srec, umap.tag, umap.maxOccurances != 1, umap.minOccurances == 0);
        }
    }
    context.typeRecords[typeName] = sgrec;
    return sgrec;
}

function generateRecordForSegment(edi:EdiSegSchema segmap, GenContext context) returns BalRecord|error {
    string sTypeName = startWithUppercase(segmap.tag + "_Type");
    BalRecord? erec = context.typeRecords[sTypeName];
    if erec is BalRecord {
        return erec;
    }

    BalRecord srec = new (sTypeName);
    foreach edi:EdiFieldSchema emap in segmap.fields {
        BalType? balType = ediToBalTypes[emap.dataType];
        string? defaultValue = ();
        if emap.tag == "code" {
            if balType !is BSTRING {
                return error("Code field must be of type string. Segment: " + segmap.toString());
            }
            defaultValue = segmap.code;
            emap.required = true;
        }

        if emap.dataType == edi:COMPOSITE {
            balType = generateRecordForComposite(emap, context);
        }

        if balType is BalType {
            srec.addField(balType, emap.tag, emap.repeat, !emap.required, defaultValue);
        }
    }
    context.typeRecords[sTypeName] = srec;
    return srec;
}

function generateRecordForComposite(edi:EdiFieldSchema emap, GenContext context) returns BalRecord {
    BalRecord newRec = new (emap.tag);
    foreach edi:EdiComponentSchema submap in emap.components {
        BalType? balType = ediToBalTypes[submap.dataType];
        if balType is BalType {
            newRec.addField(balType, submap.tag, false, !submap.required);
        }
    }
    int? num = context.typeNumber[emap.tag];
    if num is int {
        foreach int i in 1...num {
            string index = i == 1 ? "" : i.toString();
            string cTypeName = startWithUppercase(string `${emap.tag}${index}_GType`);
            BalRecord? crec = context.typeRecords[cTypeName];
            if crec is BalRecord {
                newRec.name = cTypeName;
                if newRec.isEqual(crec) {
                    return crec;
                }
            }
        }
    }
    string cTypeName = generateTypeName(emap.tag, context);
    BalRecord crec = new (cTypeName);
    foreach edi:EdiComponentSchema submap in emap.components {
        BalType? balType = ediToBalTypes[submap.dataType];
        if balType is BalType {
            crec.addField(balType, submap.tag, false, !submap.required);
        }
    }
    context.typeRecords[cTypeName] = crec;
    return crec;
}

function startWithUppercase(string s) returns string {
    string newS = s.trim();
    if newS.length() == 0 {
        return s;
    }
    string firstLetter = newS.substring(0, 1);
    newS = firstLetter.toUpperAscii() + newS.substring(1, newS.length());
    return newS;
}

function generateTypeName(string tag, GenContext context) returns string {
    int? num = context.typeNumber[tag];
    if num is int {
        int newNum = num + 1;
        log:printDebug(string `Entity name occurs multiple times. Modifying the name of the corresponding generated type to avoid conflicts.
            Entity: ${tag}, Occurances: ${newNum}`);
        context.typeNumber[tag] = newNum;
        return startWithUppercase(string `${tag}${newNum}_GType`);
    } else {
        int newNum = 1;
        context.typeNumber[tag] = newNum;
        return startWithUppercase(tag + "_GType");
    }
}

type ValueType string|int|float|decimal|boolean;

public class BalRecord {
    string name;
    BalField[] fields = [];
    boolean closed = true;
    boolean publicRecord = true;

    function init(string name) {
        self.name = name;
    }

    function addField(BalType btype, string name, boolean array, boolean optional, ValueType? defaultValue = ()) {
        self.fields.push(new BalField(btype, name, array, optional, defaultValue));
    }

    function toString(boolean... anonymous) returns string {
        if anonymous.length() == 0 {
            anonymous.push(false);
        }
        string recString = string `record {${self.closed ? "|" : ""}` + "\n";
        foreach BalField f in self.fields {
            recString += "   " + f.toString(anonymous[0]) + "\n";
        }
        recString += string `${self.closed ? "|" : ""}};` + "\n";

        if !anonymous[0] {
            recString = string `${self.publicRecord ? "public" : ""} type ${self.name} ${recString}`;
        }
        return recString;
    }

    function isEqual(BalRecord other) returns boolean {
        if self.name != other.name {
            return false;
        }
        if self.publicRecord != other.publicRecord {
            return false;
        }
        if self.closed != other.closed {
            return false;
        }
        if self.fields.length() != other.fields.length() {
            return false;
        }
        foreach int i in 0...self.fields.length() - 1 {
            BalField f1 = self.fields[i];    
            BalField f2 = other.fields[i];
            if !f1.isEqual(f2) {
                return false;
            }    
        }
        return true;
    }
}

class BalField {
    string name;
    BalType btype;
    ValueType? defaultValue;
    boolean array = false;
    boolean optional = true;

    function init(BalType btype, string name, boolean array, boolean optional, ValueType? defaultValue = ()) {
        self.btype = btype;
        self.name = name;
        self.defaultValue = defaultValue;
        self.array = array;
        self.optional = optional;
    }

    function isEqual(BalField other) returns boolean {
        if self.btype is BalRecord {
            return false;
        }
        if  other.btype is BalRecord {
            return false;
        }
        return self.name == other.name && 
            compareBalTypes(self.btype, other.btype) && 
            self.array == other.array && 
            self.defaultValue == other.defaultValue &&
            self.optional == other.optional;
    }

    function toString(boolean... anonymous) returns string {
        if anonymous.length() == 0 {
            anonymous.push(false);
        }

        BalType t = self.btype;
        string typeName = "";
        if t is BalRecord {
            if anonymous[0] {
                typeName = t.toString(true);
            } else {
                typeName = t.name;
            }
        } else {
            typeName = t.toString();
        }
        // string typeName = t is BalRecord? t.name : t.toString();
        string assignment = self.defaultValue is () ? (self.array ? " = []" : "") : string ` = ${self.defaultValue is string ? "\"" : ""}${self.defaultValue.toString()}${self.defaultValue is string ? "\"" : ""}`;
        return string `${typeName}${(self.optional && !self.array && self.btype != BSTRING) ? "?" : ""}${self.array ? "[]" : ""} ${self.name}${(self.optional && !self.array) ? "?" : ""}${assignment};`;
    }
}

public type BalType BalBasicType|BalRecord;

public enum BalBasicType {
    BSTRING = "string", BINT = "int", BFLOAT = "float", BBOOLEAN = "boolean"
}

function compareBalTypes(BalType t1, BalType t2) returns boolean {
    if t1 is BalRecord && t2 is BalRecord {
        return t1.isEqual(t2);
    }
    if t1 is BalBasicType && t2 is BalBasicType {
        return t1 == t2;
    }
    return false;
}
