
public enum EDIDataType {
    STRING = "string", INT = "int", FLOAT = "float", COMPOSITE = "composite"
}

type SimpleType string|int|float;

type SimpleArray string[]|int[]|float[];

public type EDIDoc map<EDISegment|EDISegment[]?>;

public type EDISegmentGroup record {|
    EDISegment|EDISegment[]|EDISegmentGroup|EDISegmentGroup[]...;
|};

public type EDISegment map<EDIComponentGroup|EDIComponentGroup[]|SimpleType|SimpleArray?>;

public type EDIUnit EDISegment|EDISegmentGroup;

public type EDIComponentGroup map<SimpleType|SimpleArray|EDISubcomponentGroup?>;

public type EDISubcomponentGroup map<SimpleType?>;