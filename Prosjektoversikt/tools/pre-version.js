/**
 * This script updates the package-solution version analogue to the
 * the package.json file.
 */

if (process.env.npm_package_version === undefined) {
    throw 'Package version cannot be evaluated';
}

const solution = './config/package-solution.json',
    webpart = './src/projectOverview/manifest.json'

// require filesystem instance
const fs = require('fs');

// get next automated package version from process variable
const nextPkgVersion = process.env.npm_package_version;

// make sure next build version match
const nextVersion = nextPkgVersion.indexOf('-') === -1 ?
    nextPkgVersion : nextPkgVersion.split('-')[0];

if (fs.existsSync(solution)) {
    const solutionFileContent = fs.readFileSync(solution, 'UTF-8');
    const solutionContents = JSON.parse(solutionFileContent);

    solutionContents.solution.version = nextVersion + '.0';


    fs.writeFileSync(
        solution,
        JSON.stringify(solutionContents, null, 2),
        'UTF-8');

}
if (fs.existsSync(webpart)) {
    const webpartManifestContent = fs.readFileSync(webpart, 'UTF-8');
    const webpartContent = JSON.parse(webpartManifestContent);

    // set property of version to next version
    webpartContent.version = nextVersion;

    // save file
    fs.writeFileSync(
        webpart,
        // convert file back to proper json
        JSON.stringify(webpartContent, null, 2),
        'UTF-8');

}
