function generateBallerinaToml(LibData libdata) returns string {
    return string `
[package]
org = "${libdata.orgName}"
name = "${libdata.libName}"
version = "0.1.0"
distribution = "2201.5.0"
export=[${libdata.exportsBlock}]
`;
}
