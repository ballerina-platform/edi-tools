
class EDIWriter {

    EDIMapping emap;
    SegmentGroupWriter segmentGroupSerializer;

    function init(EDIMapping emap) {
        self.emap = emap;
        self.segmentGroupSerializer = new(emap);
    }

    function writeEDI(json msg) returns string|error {
        string[] ediText = [];
        if !(msg is map<json>) {
            return error(string `Input is not compatible with the schema.`);
        }
        check self.segmentGroupSerializer.serialize(msg, self.emap, ediText);
        string ediOutput = "";
        foreach string s in ediText {
            ediOutput += s + (self.emap.delimiters.segment == "\n"? "" : "\n");
        }
        return ediOutput;
    }
}