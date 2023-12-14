import ballerina/http;
import ballerina/lang.regexp;
import ballerina/log;
import ballerina/io;

type Segement record {|
    string ref;
    string tag;
    int minOccurances?;
    int maxOccurances;
|};

type SegmentGroup record {|
    string tag;
    int minOccurances?;
    int maxOccurances;
    (Segement|SegmentGroup)[] segments;
|};

type SegmentDef record {|
    string code;
    string tag;
    FieldDef[] fields;
|};

type FieldDef record {|
    string tag;
    string dataType?;
    boolean required = false;
    boolean repeat = false;
    ComponentDef[] components?;
|};

type ComponentDef record {|
    string tag;
    boolean required = false;
    string dataType?;
|};

type Delimiters record {|
    string segment = "'";
    string 'field = "+";
    string component = ":";
    string repetition = "^";
    string decimalSeparator = ",";
|};

type SegmentDefintions map<SegmentDef>;

type EDISchema record {|
    string name;
    string[] ignoreSegments;
    Delimiters delimiters;
    (Segement|SegmentGroup)[] segments;
    SegmentDefintions segmentDefinitions;
|};

final http:Client edifactClient = check new ("https://service.unece.org/");
readonly & string edifactApi = "";

final string:RegExp msgTypeReg = re `<A HREF = "([^"]+)">([^<]+)</A>`;

final regexp:RegExp segementTableReg = re `\d+\.\d+\.\d+  Segment table([\s\S]+)`;

final regexp:RegExp segmentGroupReg = re `Segment group (\d+)\s+------------------\s+([CM])\s+(\d+)(-+\+*\|*)`;
final regexp:RegExp segmentGroupOrSegmentReg = re `<A HREF = "\.\./([^"]+)">([^<]+)</A>\s+(.*)\s+([CM])\s+(\d+)([\s-]+\+*\|*)|Segment group (\d+)\s+------------------\s+([CM])\s+(\d+)(-+\+*\|*)`;

final regexp:RegExp fieldAndComponentReg = re `(\d+)\s+<A HREF = "\.\./([^"]+)">([^<]+)</A>\s+(.*)\s+([CM])\s+(\d+.*)|       <A HREF = "\.\./([^"]+)">([^<]+)</A>\s+([A-Za-z-\n\s]*)\s+([CM])`;
final regexp:RegExp fieldReg = re `(\d+)\s+<A HREF = "\.\./([^"]+)">([^<]+)</A>\s+(.*)\s+([CM])\s+(\d+.*)`;

final regexp:RegExp componentNameReg = re `<H3>[|*]?\s+(\d+)\s+([^<]+)\s+\[[A-Za-z]+\]?\s*</H3>`;
final regexp:RegExp componentTypeReg = re `Repr:(.*)`;

public function convertEdifactToEdi(string version, string dir, string? messageType = ()) returns error? {
    edifactApi = "trade/untdid/" + version + "/";
    string msgTypesUrl = edifactApi + "trmd/";
    http:Response msgTypesRes = check edifactClient->get(msgTypesUrl + "trmdi1.htm");
    if msgTypesRes.statusCode != 200 {
        return error("Invalid version " + version + " is given");
    }
    string msgTypes = check msgTypesRes.getTextPayload();

    SegmentDefintions allSegmentDefinitions = {};
    regexp:Groups[] msgGroups = msgTypeReg.findAllGroups(msgTypes);    
    foreach var msgGroup in msgGroups {
        regexp:Span? urlMatch = msgGroup[1];
        regexp:Span? codeMatch = msgGroup[2];
        if urlMatch is () || codeMatch is () {
            return error("Invalid message type is found");
        }
        string code = codeMatch.substring();
        if messageType is () {
            check genEdiSchema(msgTypesUrl + urlMatch.substring(), code, dir, allSegmentDefinitions);
        } else {
            if code == messageType {
                check genEdiSchema(msgTypesUrl + urlMatch.substring(), code, dir, allSegmentDefinitions);
                return;
            }
        }
    }
    if messageType !is () {
        return error("Invalid message type " + messageType + " is given");
    }
}

function genEdiSchema(string url, string code, string dir, SegmentDefintions allSegmentDefinitions) returns error? {
    log:printInfo("Generating EDI schema for " + code);
    http:Response msgTypeRes = check edifactClient->get(url);
    EDISchema ediSchema = check genMsgTypeEdiSchema(check msgTypeRes.getTextPayload(), allSegmentDefinitions, code);
    string dirPath = dir;
    if dir[dir.length() - 1] != "/" {
        dirPath = dir + "/";
    }
    check io:fileWriteJson(dirPath + code + ".json", ediSchema);
}

function genMsgTypeEdiSchema(string msgType, SegmentDefintions segmentDefinitions, string name) returns EDISchema|error {
    EDISchema ediSchema = {
        name,
        ignoreSegments: ["UNB"],
        delimiters: {
            segment: "'",
            'field: "+",
            component: ":",
            repetition: "*",
            decimalSeparator: ","
        },
        segments: [],
        segmentDefinitions: {}
    };

    regexp:Groups[] segmentTableGroups = segementTableReg.findAllGroups(msgType);
    if segmentTableGroups.length() != 1 {
        return error("Cannot find a match for single segment table");
    }
    regexp:Groups segmentTableGroup = segmentTableGroups[0];
    if segmentTableGroup.length() != 2 {
        return error("Segment table not found");
    }
    regexp:Span? segmentTableMatch = segmentTableGroup[1];
    if segmentTableMatch is () {
        return error("Segment table not found");
    }

    string segmentTable = segmentTableMatch.substring();
    regexp:Groups[] segments = segmentGroupOrSegmentReg.findAllGroups(segmentTable);

    check genSegmentsSchema(segments, segmentDefinitions, ediSchema.segments, ediSchema.segmentDefinitions);
    return ediSchema;
}

function genSegmentsSchema(regexp:Groups[] segmentsMatch, map<SegmentDef> allSegmentDefinitions, (Segement|SegmentGroup)[] segments, SegmentDefintions segmentDefintions) returns error? {
    int currentDepth = 0;
    SegmentGroup[] segmentGroupsSeq = [];
    SegmentGroup? currentGroup = ();
    foreach var segmentMatch in segmentsMatch {
        if segmentGroupReg.isFullMatch(segmentMatch[0].substring()) {
            var [segmentGroup, depth] = check genSegmentGroupSchema(segmentMatch, segments);
            if depth == 0 {
                segmentGroupsSeq = [segmentGroup];
                segments.push(segmentGroup);
                currentDepth = 0;
            } else if currentDepth == depth {
                _ = segmentGroupsSeq.pop();
                segmentGroupsSeq[segmentGroupsSeq.length() - 1].segments.push(segmentGroup);
                segmentGroupsSeq.push(segmentGroup);
            } else if currentDepth < depth {
                segmentGroupsSeq[segmentGroupsSeq.length() - 1].segments.push(segmentGroup);
                segmentGroupsSeq.push(segmentGroup);
                currentDepth = depth;
            } else {
                int depthDiff = currentDepth - depth;
                foreach int i in 0 ..< depthDiff {
                    _ = segmentGroupsSeq.pop();
                    currentDepth = currentDepth - 1;
                }
                _ = segmentGroupsSeq.pop();
                segmentGroupsSeq[segmentGroupsSeq.length() - 1].segments.push(segmentGroup);
                segmentGroupsSeq.push(segmentGroup);
            }
        } else {
            if segmentGroupsSeq.length() > 0 {
                currentGroup = segmentGroupsSeq[segmentGroupsSeq.length() - 1];
                regexp:Span? rest = segmentMatch[6];
                if rest !is () && rest.substring().trim() == "" {
                    currentGroup = ();
                }
            }
            check genSementSchema(segmentMatch, allSegmentDefinitions, currentGroup, segments, segmentDefintions);
        }
    }
}

function genSegmentGroupSchema(regexp:Groups segmentGroupMatch, (Segement|SegmentGroup)[] segments) returns [SegmentGroup, int]|error {
    regexp:Span? groupNumber = segmentGroupMatch[1];
    regexp:Span? status = segmentGroupMatch[2];
    regexp:Span? occurance = segmentGroupMatch[3];
    regexp:Span? depthMatch = segmentGroupMatch[4];
    if groupNumber is () || status is () || occurance is () || depthMatch is () {
        return error("Invalid segment group found");
    }
    int depth = getDepth(depthMatch.substring());
    string groupName = "group_" + groupNumber.substring();
    SegmentGroup group = {
        "tag": groupName,
        "minOccurances": getMinOccurances(status.substring()),
        "maxOccurances": check int:fromString(occurance.substring()),
        segments: []
    };
    return [group, depth];
}

function genSementSchema(regexp:Groups segmentMatch, map<SegmentDef> allSegmentDefinitions, SegmentGroup? currentGroup, (Segement|SegmentGroup)[] segments, SegmentDefintions segmentDefintions) returns error? {
    regexp:Span? url = segmentMatch[1];
    regexp:Span? codeMatch = segmentMatch[2];
    regexp:Span? descriptionMatch = segmentMatch[3];
    regexp:Span? status = segmentMatch[4];
    regexp:Span? occurance = segmentMatch[5];
    regexp:Span? rest = segmentMatch[6];
    if url is () || codeMatch is () || descriptionMatch is () || status is () || occurance is () || rest is () {
        return error("Invalid segment found");
    }

    string code = codeMatch.substring();
    string tag = getTag(descriptionMatch.substring().trim());
    Segement segment = {
        "ref": code,
        tag,
        "minOccurances": getMinOccurances(status.substring()),
        "maxOccurances": check int:fromString(occurance.substring())
    };
    if currentGroup is () {
        segments.push(segment);
    } else {
        currentGroup.segments.push(segment);
    }
    if !segmentDefintions.hasKey(code) {
        SegmentDef? seg = allSegmentDefinitions[code];
        if seg is () {
            http:Response segementPage = check edifactClient->get(edifactApi + url.substring());
            if code == "UNH" {
                allSegmentDefinitions[code] = UNH;
                segmentDefintions[code] = UNH;
            } else if code == "UNT" {
                allSegmentDefinitions[code] = UNT;
                segmentDefintions[code] = UNT;
            } else if code == "UNS" {
                allSegmentDefinitions[code] = UNS;
                segmentDefintions[code] = UNS;
            } else if code == "DTM" {
                allSegmentDefinitions[code] = DTM;
                segmentDefintions[code] = DTM;
            } else {
                if segementPage.statusCode == 200 {
                    SegmentDef currentSegmentDef = check getSegmentDef(check segementPage.getTextPayload(), code, tag);
                    allSegmentDefinitions[code] = currentSegmentDef;
                    segmentDefintions[code] = currentSegmentDef;
                } else if segementPage.statusCode == 404 {
                    log:printDebug("Segment " + code + " not found");
                }
            }
        } else {
            segmentDefintions[code] = seg;
        }
    }
}

function getSegmentDef(string segmentPage, string code, string tag) returns SegmentDef|error {
    regexp:Groups[] fieldGroups = fieldAndComponentReg.findAllGroups(segmentPage);
    FieldDef[] fields = [{tag: "code", required: true}];
    check addFields(fields, fieldGroups);
    return {code, tag, fields};
}

function addFields(FieldDef[] fields, regexp:Groups[] fieldGroups) returns error? {
    FieldDef currentField = {...fields[0]};
    string[] componentNames = [];
    string[] fieldNames = [];
    foreach regexp:Groups fieldGroup in fieldGroups {
        if fieldReg.isFullMatch(fieldGroup[0].substring()) {
            currentField = check getField(fieldGroup, fieldNames);
            currentField.components = [];
            fields.push(currentField);
            componentNames = [];
        } else {
            (<ComponentDef[]>currentField.components).push(check getComponent(fieldGroup, componentNames));
        }
    }
}

function getComponent(regexp:Groups fieldGroup, string[] componentNames) returns ComponentDef|error {
    regexp:Span? urlMatch = fieldGroup[1];
    regexp:Span? tagMatch = fieldGroup[3];
    regexp:Span? statusMatch = fieldGroup[4];
    if urlMatch is () || statusMatch is () || tagMatch is () {
        return error("Invalid component found");
    }
    http:Response componentPageRes = check edifactClient->get(edifactApi + urlMatch.substring().trim());
    if componentPageRes.statusCode != 200 {
        return error("Invalid component found");
    }
    // TODO: if 400, use matches to parse data.
    string componentPage = check componentPageRes.getTextPayload();
    regexp:Groups typeGroups = componentTypeReg.findAllGroups(componentPage)[0];
    regexp:Span? typeMatch = typeGroups[1];
    if typeMatch is () {
        return error("Invalid component found");
    }
    regexp:Groups componentNameGroups = componentNameReg.findAllGroups(componentPage)[0];
    regexp:Span? componentNameMatch = componentNameGroups[2];
    if componentNameMatch is () {
        return error("Invalid component found");
    }

    return {
        tag: getComponentName(componentNames, getTag(componentNameMatch.substring().trim())),
        required: statusMatch.substring() == "M" ? true : false,
        dataType: getType(typeMatch.substring().trim())
    };
}

function getField(regexp:Groups fieldGroup, string[] fieldNames) returns FieldDef|error {
    regexp:Span? tagMatch = fieldGroup[4];
    regexp:Span? statusMatch = fieldGroup[5];
    regexp:Span? occuranceAndTypeMatch = fieldGroup[6];
    if tagMatch is () || statusMatch is () || occuranceAndTypeMatch is () {
        return error("Invalid field found");
    }
    string occuranceAndType = occuranceAndTypeMatch.substring().trim();
    regexp:RegExp occuranceAndTypeReg = re `(\d+)\s*(.*)`;
    regexp:Groups occuranceAndTypeGroups = occuranceAndTypeReg.findAllGroups(occuranceAndType)[0];
    regexp:Span? occuranceMatch = occuranceAndTypeGroups[1];
    if occuranceMatch is () {
        return error("Invalid field found");
    }
    int occurance = check int:fromString(occuranceMatch.substring());
    regexp:Span? typeMatch = occuranceAndTypeGroups[2];
    if typeMatch is () {
        return error("Invalid field type found");
    }
    string? 'type = ();
    string typeString = typeMatch.substring().trim();
    if typeString == "" {
        'type = "composite";
    } else {
        'type = getType(typeString);
    }
    return {tag: getFieldNames(fieldNames, getTag(tagMatch.substring().trim())), dataType: 'type, repeat: occurance > 1 ? true : false};
}

function getTag(string description) returns string {
    string tag = "";
    foreach string c in description {
        if c != " " && c != "/" && c != "-" && c != "&" {
            tag = tag.concat(c);
        } else {
            tag = tag.concat("_");
        }
    }
    return tag;
}

function getMinOccurances(string occurance) returns int? {
    return occurance == "M" ? 1 : ();
}

function getType(string t) returns string? {
    if t.includes("an..") {
        return "string";
    } else if t.includes("n..") {
        return "int";
    }
    // TODO: Support for float
    return ();
}

function getDepth(string s) returns int {
    int depth = 0;
    foreach string c in s {
        if c == "|" {
            depth = depth + 1;
        }
    }
    return depth;
}

function isSingleSegment(string s) returns boolean {
    return !s.includes("|");
}

// In original spec, there are some components with same name. This function will add a number to the end of the name
// Otherwise, it will generate Ballerina fields with same name.
function getComponentName(string[] componentNames, string tag) returns string {
    int length = componentNames.length();
    foreach var name in componentNames {
        if name == tag {
            string newName = tag + "_" + length.toString();
            componentNames.push(newName);
            return newName;
        }
    }
    componentNames.push(tag);
    return tag;
}

function getFieldNames(string[] fieldNames, string tag) returns string {
    int length = fieldNames.length();
    foreach var name in fieldNames {
        if name == tag {
            string newName = tag + "_" + length.toString();
            fieldNames.push(newName);
            return newName;
        }
    }
    fieldNames.push(tag);
    return tag;
}
