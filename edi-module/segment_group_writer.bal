class SegmentGroupWriter {

    EDISchema schema;
    SegmentWriter segmentSerializer;

    function init(EDISchema schema) {
        self.schema = schema;
        self.segmentSerializer = new(schema);
    }

    function serialize(map<json> segGroup, EDISegGroupSchema|EDISchema sgmap, string[] ediText) returns error? {

        string[] keys = segGroup.keys();
        int msgIndex = 0;
        int mapIndex = 0;
        while mapIndex < sgmap.segments.length() {
            EDIUnitSchema umap = sgmap.segments[mapIndex];
            if msgIndex >= keys.length() {
                if umap.minOccurances > 0 {
                    return error(string `Mandatory segment ${umap.tag} not found in input message.`);
                }
                mapIndex += 1;
                continue;
            }
            string unitKey = keys[msgIndex];
            json unit = segGroup.get(unitKey);
            if umap.tag != unitKey {
                if umap.minOccurances == 0 {
                    mapIndex += 1;
                    continue;
                } else {
                    return error(string `Mandatory segment ${umap.tag} not found in input message. Found ${unitKey}`);
                }
            }

            if umap.maxOccurances == 1 {
                if !(unit is map<json>) {
                    return error(string `Segment group "${sgmap.tag} must contain segments or segment groups. Found: ${unit.toString()}"`);
                }
                if umap is EDISegSchema {
                    check self.segmentSerializer.serialize(unit, umap, ediText);
                } else if umap is EDISegGroupSchema {
                    check self.serialize(unit, umap, ediText);
                }
            } else if umap.maxOccurances > 1 || umap.maxOccurances == -1 {
                if !(unit is json[]) {
                    return error(string `Value of segment/segment group "${umap.tag}" must be an array. Found: ${unit.toString()}`);
                }
                if unit.length() >= umap.minOccurances && ((unit.length() <= umap.maxOccurances) || umap.maxOccurances < 0) {
                    foreach json u in unit {
                        if !(u is map<json>) {
                            return error(string `Each item in ${umap.tag} must be a segment/segment group. Found: ${u.toString()}`);
                        }
                        if umap is EDISegSchema {
                            check self.segmentSerializer.serialize(u, umap, ediText);
                        } else if umap is EDISegGroupSchema {
                            check self.serialize(u, umap, ediText);
                        }
                    }  
                }

            } else {
                return error(string `Cardinality of input segment/segment group "${unitKey}" does not match with schema ${printEDIUnitMapping(umap)}.
                Allowed min: ${umap.minOccurances}, Allowed max: ${umap.maxOccurances}, Found ${unit is EDIUnit[]? unit.length() : 1}`);
            }
            mapIndex += 1;
            msgIndex += 1;
        }

    }
}

type EDIU map<json>;