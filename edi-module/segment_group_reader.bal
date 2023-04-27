import ballerina/log;
import ballerina/regex;

type SegmentGroupContext record {|
    int mappingIndex = 0;
    EDISegmentGroup segmentGroup = {};
    EDIUnitSchema[] unitSchemas;
|};

class SegmentGroupReader {

    SegmentReader segmentReader = new();

    function read(EDIUnitSchema[] currentMapping, EDIContext context, boolean rootGroup) returns EDISegmentGroup|error {
        SegmentGroupContext sgContext = {unitSchemas: currentMapping};
        EDISchema ediSchema = context.schema;
        while context.rawIndex < context.rawSegments.length() {
            string sDesc = context.rawSegments[context.rawIndex];
            string segmentDesc = regex:replaceAll(sDesc, "\n", "");
            string[] fields = split(segmentDesc, ediSchema.delimiters.'field);
            if ediSchema.ignoreSegments.indexOf(fields[0], 0) != null {
                context.rawIndex += 1;
                continue;
            }

            boolean segmentMapped = false;
            while sgContext.mappingIndex < sgContext.unitSchemas.length() {
                EDIUnitSchema? segMapping = currentMapping[sgContext.mappingIndex];
                if (segMapping is EDISegSchema) {
                    log:printDebug(string `Trying to match with segment mapping ${printSegMap(segMapping)}`);
                    if segMapping.code != fields[0] {
                        check self.ignoreMapping(segMapping, sgContext, context);
                        continue;
                    }
                    EDISegment ediRecord = check self.segmentReader.read(segMapping, fields, ediSchema, segmentDesc);
                    check self.placeEDISegment(ediRecord, segMapping, sgContext, context);
                    context.rawIndex += 1;
                    segmentMapped = true;
                    break;

                } else if segMapping is EDISegGroupSchema {
                    log:printDebug(string `Trying to match with segment group mapping ${printSegGroupMap(segMapping)}`);
                    EDIUnitSchema firstSegMapping = segMapping.segments[0];
                    if firstSegMapping is EDISegGroupSchema {
                        return error("First item of segment group must be a segment. Found a segment group.\nSegment group: " + printSegGroupMap(segMapping));
                    }
                    if firstSegMapping.code != fields[0] {
                        check self.ignoreMapping(segMapping, sgContext, context);
                        continue;
                    }
                    EDISegmentGroup segmentGroup = check self.read(segMapping.segments, context, false);
                    if segmentGroup.length() > 0 {
                        check self.placeEDISegmentGroup(segmentGroup, segMapping, sgContext, context);
                    }
                    segmentMapped = true;
                    break;
                }
            }
            if !segmentMapped && rootGroup {
                return error(string `Segment text: ${context.rawSegments[context.rawIndex]} is not matched with the mapping.
                Curren row: ${context.rawIndex}`);
            }

            if sgContext.mappingIndex >= sgContext.unitSchemas.length() {
                // We have completed mapping with this segment group.
                break;
            }
        }
        check self.validateRemainingMappings(sgContext);
        return sgContext.segmentGroup;
    }

    # Ignores the given mapping if any of the below two conditions are satisfied. This function will be called
    # if a mapping cannot be mapped with the next available segment text.
    # 
    #   1. Given mapping is optional
    #   2. Given mapping is a repeatable one and it has already occured at least once
    # 
    # If above conditions are not met, mapping cannot be ignored, and should result in an error. 
    #
    # + segMapping - Segment mapping or segment group mapping to be ignored
    # + sgContext - Segment group parsing context  
    # + context - EDI parsing context
    # + return - Return error if the given mapping cannot be ignored.
    function ignoreMapping(EDIUnitSchema segMapping, SegmentGroupContext sgContext, EDIContext context) returns error? {

        // If the current segment mapping is optional, we can ignore the current mapping and compare the 
        // current segment with the next mapping.
        if segMapping.minOccurances == 0 {
            log:printDebug(string `Ignoring optional segment: ${printEDIUnitMapping(segMapping)} | Segment text: ${context.rawIndex < context.rawSegments.length()? context.rawSegments[context.rawIndex] : "-- EOF --"}`);
            sgContext.mappingIndex += 1;
            return;
        }

        // If the current segment mapping represents a repeatable segment, and we have already encountered 
        // at least one such segment, we can ignore the current mapping and compare the current segment with 
        // the next mapping.
        if segMapping.maxOccurances != 1 {
            var segments = sgContext.segmentGroup[segMapping.tag];
            if (segments is EDISegment[]|EDISegmentGroup[]) {
                if segments.length() > 0 {
                    // This repeatable segment has already occured at least once. So move to the next mapping.
                    sgContext.mappingIndex += 1;
                    log:printDebug(string `Completed reading repeatable segment: ${printEDIUnitMapping(segMapping)} | Segment text: ${context.rawIndex < context.rawSegments.length()? context.rawSegments[context.rawIndex] : "-- EOF --"}`);
                    return;
                } 
            }   
        }  

        return error(string `Mandatory unit ${printEDIUnitMapping(segMapping)} missing in the EDI.
        Current segment text: ${context.rawSegments[context.rawIndex]}
        Current mapping index: ${sgContext.mappingIndex}`);
    }

    function placeEDISegment(EDISegment segment, EDISegSchema segMapping, SegmentGroupContext sgContext, EDIContext context) returns error? {
        if (segMapping.maxOccurances == 1) {
            // Current segment has matched with the current mapping AND current segment is not repeatable.
            // So we can move to the next mapping.
            log:printDebug(string `Completed reading non-repeatable segment: ${printSegMap(segMapping)}.
            Segment text: ${context.rawSegments[context.rawIndex]}`);
            sgContext.mappingIndex += 1;
            sgContext.segmentGroup[segMapping.tag] = segment;
        } else {
            // Current mapping points to a repeatable segment. So we are using a EDISegment[] array to hold segments.
            // Also we can't increment the mapping index here as next segment can also match with the current mapping
            // as the segment is repeatable.
            var segments = sgContext.segmentGroup[segMapping.tag];
            if (segments is EDISegment[]) {
                if (segMapping.maxOccurances != -1 && segments.length() >= segMapping.maxOccurances) {
                    return error(string `${segMapping.code} is repeatable segment with maximum limit of ${segMapping.maxOccurances}.
                    EDI document contains more such segments than the allowed limit. Current row: ${context.rawIndex}`);
                }
                segments.push(segment);
            } else if segments is null {
                segments = [segment];
                sgContext.segmentGroup[segMapping.tag] = segments;
            } else {
                return error(string `${segMapping.code} must be a segment array.`);
            }
        }  
    }

    function placeEDISegmentGroup(EDISegmentGroup segmentGroup, EDISegGroupSchema segMapping, SegmentGroupContext sgContext, EDIContext context) returns error? {
        if segMapping.maxOccurances == 1 {
            // This is a non-repeatable mapping. So we have to compare the next segment with the next mapping.
            log:printDebug(string `Completed reading non-repeating segment group ${printSegGroupMap(segMapping)} | Current segment text: ${context.rawIndex < context.rawSegments.length()? context.rawSegments[context.rawIndex] : "-- EOF --"}`);
            sgContext.mappingIndex += 1;
            sgContext.segmentGroup[segMapping.tag] = segmentGroup;
        } else {
            // This is a repeatable mapping. So we compare the next segment also with the current mapping.
            // i.e. we don't increment the mapping index.
            var segmentGroups = sgContext.segmentGroup[segMapping.tag];
            if segmentGroups is EDISegmentGroup[] {
                if segMapping.maxOccurances != -1 && segmentGroups.length() >= segMapping.maxOccurances {
                    return error(string `${printSegGroupMap(segMapping)} is repeatable segment group with maximum limit of ${segMapping.maxOccurances}.
                    EDI document contains more such segment groups than the allowed limit. Current row: ${context.rawIndex}`);    
                }
                segmentGroups.push(segmentGroup);
            } else if segmentGroups is null {
                segmentGroups = [segmentGroup];
                sgContext.segmentGroup[segMapping.tag] = segmentGroups;
            } else {
                return error(string `${segMapping.tag} must be a segment group array.`);
            }
            
        }
    }

    function validateRemainingMappings(SegmentGroupContext sgContext) returns error? {
        if sgContext.mappingIndex < sgContext.unitSchemas.length() - 1 {
                int i = sgContext.mappingIndex + 1;
                while i < sgContext.unitSchemas.length() {
                    EDIUnitSchema umap = sgContext.unitSchemas[i];
                    int minOccurs = 1;
                    if umap is EDISegSchema {
                        minOccurs = umap.minOccurances;
                    } else {
                        minOccurs = umap.minOccurances;
                    }
                    if minOccurs > 0 {
                        return error(string `Mandatory segment ${printEDIUnitMapping(umap)} is not found.`);
                    }
                    i += 1;
                }
            }
    }
}