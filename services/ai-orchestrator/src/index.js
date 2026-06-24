const { orchestratorManifest } = require("./manifest");

function main() {
  console.log(JSON.stringify(orchestratorManifest, null, 2));
  console.log("No model calls are configured in the project spine.");
}

main();
