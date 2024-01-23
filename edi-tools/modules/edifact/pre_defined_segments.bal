// There are some cases segment web pages are not available. 
// Those segments are defined here. 
// If these segments are not equal for each version or catagory, a map should be used.

final SegmentDef UNH = {
    code: "UNH",
    tag: "message_header",
    fields: [
        {
            tag: "code",
            required: true
        },
        {
            tag: "message_reference_number",
            dataType: "string"
        },
        {
            tag: "message_information",
            dataType: "composite",
            components: [
                {
                    tag: "name",
                    dataType: "string"
                },
                {
                    tag: "catagory",
                    dataType: "string"
                },
                {
                    tag: "version",
                    dataType: "string"
                },
                {
                    tag: "status",
                    dataType: "string"
                },
                {
                    tag: "new_field",
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
        {
            tag: "number1",
            dataType: "string"
        },
        {
            tag: "number2",
            dataType: "string"
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
