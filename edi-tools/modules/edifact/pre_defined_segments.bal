// There are some cases segment web pages are not available.
// Those segments are defined here.
// If these segments are not equal for each version or catagory, a map should be used.

// Full UN/EDIFACT UNB definition (interchange header). Composites are modeled
// with all standard components — conformant input such as a 3-component S002
// (`SENDER:ZZ:INTERNAL`) must parse cleanly. Trailing optional fields and
// components rely on the runtime's `truncatable` default (true), so callers
// that omit them still parse cleanly.
final SegmentDef UNB = {
    code: "UNB",
    tag: "interchange_header",
    fields: [
        {tag: "code", required: true},
        {
            // S001 Syntax identifier
            tag: "syntax_identifier",
            dataType: "composite",
            required: true,
            components: [
                {tag: "syntax_id", dataType: "string", required: true},
                {tag: "syntax_version", dataType: "string", required: true},
                {tag: "service_code_list_directory_version", dataType: "string"},
                {tag: "character_encoding", dataType: "string"}
            ]
        },
        {
            // S002 Interchange sender
            tag: "sender",
            dataType: "composite",
            required: true,
            components: [
                {tag: "id", dataType: "string", required: true},
                {tag: "qualifier", dataType: "string"},
                {tag: "internal_id", dataType: "string"},
                {tag: "internal_sub_id", dataType: "string"}
            ]
        },
        {
            // S003 Interchange recipient
            tag: "recipient",
            dataType: "composite",
            required: true,
            components: [
                {tag: "id", dataType: "string", required: true},
                {tag: "qualifier", dataType: "string"},
                {tag: "internal_id", dataType: "string"},
                {tag: "internal_sub_id", dataType: "string"}
            ]
        },
        {
            // S004 Date and time of preparation
            tag: "date_and_time",
            dataType: "composite",
            required: true,
            components: [
                {tag: "date", dataType: "string", required: true},
                {tag: "time", dataType: "string", required: true}
            ]
        },
        // 0020 Interchange control reference
        {tag: "control_reference", dataType: "string", required: true},
        {
            // S005 Recipient's reference/password details
            tag: "recipient_reference_password",
            dataType: "composite",
            components: [
                {tag: "reference_password", dataType: "string"},
                {tag: "qualifier", dataType: "string"}
            ]
        },
        {tag: "application_reference", dataType: "string"},
        {tag: "processing_priority_code", dataType: "string"},
        {tag: "acknowledgement_request", dataType: "string"},
        {tag: "communications_agreement_id", dataType: "string"},
        {tag: "test_indicator", dataType: "string"}
    ]
};

final SegmentDef UNZ = {
    code: "UNZ",
    tag: "interchange_trailer",
    fields: [
        {tag: "code", required: true},
        {tag: "interchange_control_count", dataType: "int", required: true},
        {tag: "interchange_control_reference", dataType: "string", required: true}
    ]
};

// UN/EDIFACT UNH definition (message header) with the full S009 message
// identifier composite (7 components). The first four are mandatory per the
// standard; the trailing three are optional and may be truncated.
final SegmentDef UNH = {
    code: "UNH",
    tag: "message_header",
    fields: [
        {
            tag: "code",
            required: true
        },
        // 0062 Message reference number
        {
            tag: "message_reference_number",
            dataType: "string",
            required: true
        },
        {
            // S009 Message identifier
            tag: "message_identifier",
            dataType: "composite",
            required: true,
            components: [
                {
                    tag: "message_type",
                    dataType: "string",
                    required: true
                },
                {
                    tag: "message_version_number",
                    dataType: "string",
                    required: true
                },
                {
                    tag: "message_release_number",
                    dataType: "string",
                    required: true
                },
                {
                    tag: "controlling_agency",
                    dataType: "string",
                    required: true
                },
                {
                    tag: "association_assigned_code",
                    dataType: "string"
                },
                {
                    tag: "code_list_directory_version",
                    dataType: "string"
                },
                {
                    tag: "message_type_sub_function",
                    dataType: "string"
                }
            ]
        }
    ]
};

final SegmentDef UNT = {
    code: "UNT",
    tag: "message_trailer",
    fields: [
        {
            tag: "code",
            required: true
        },
        // 0074 Number of segments in the message
        {
            tag: "number_of_segments",
            dataType: "int",
            required: true
        },
        // 0062 Message reference number — must match the UNH value
        {
            tag: "message_reference_number",
            dataType: "string",
            required: true
        }
    ]
};

final SegmentDef UNS = {
    code: "UNS",
    tag: "section_control",
    fields: [
        {
            tag: "code",
            required: true
        },
        {
            tag: "section_identification",
            dataType: "string",
            required: true
        }
    ]
};

final SegmentDef DTM = {
    code: "DTM",
    tag: "Date_time_period",
    fields: [
        {
            tag: "code",
            required: true
        },
        {
            tag: "DATE_TIME_PERIOD",
            dataType: "composite",
            required: false,
            components: [
                {
                    tag: "Date_or_time_or_period",
                    dataType: "string"
                },
                {
                    tag: "Date_or_time_or_period_text",
                    dataType: "string"
                },
                {
                    tag: "Date_or_time_or_period_format_code",
                    dataType: "string"
                }
            ]
        }
    ]
};
