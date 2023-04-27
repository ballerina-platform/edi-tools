string ediTrackerCode = string `
import ballerina/log;
type EDITrackingData record {
    string partnerId;
    string ediName;
    string schemaName?;
    string ediFileName?;
    string status?;
};

type EDITracker object {
    function track(EDITrackingData data) returns error?;
};

class LoggingTracker {
    * EDITracker;

    function track(EDITrackingData data) returns error? {
        log:printInfo("EDI tracking: " + data.toString());
    }
}
`;