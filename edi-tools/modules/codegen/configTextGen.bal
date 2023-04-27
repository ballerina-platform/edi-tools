function generateConfigText(string libName) returns string {

    return string `

# DO NOT store this file in a public github repository or any publically accessible location.
# Use secret value provisioning mechanism such as Kubernetes secrets or Choreo secrets to provide provide these
# values to the library runtime.

partnerId = "${libName}"

# -- EDI schema location --
# EDI schemas used for generating this module needs to be accessible during runtime. 
# Provide an HTTP(S) URL to access those schemas and an access token if authentication is required.
# For example, schemas can be stored in a Github repository and Github access URL and token can
# be provided as below.
schemaURL = "https://api.github.com/repos/<org name>/<repo name>/contents/<path>/<to>/<schema>/<location>"
schemaAccessToken = "<github token>"
`;

}