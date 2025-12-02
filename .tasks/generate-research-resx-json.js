// generate-resx-json.js

const path = require('path');
const fs = require('fs');
const { convertResx } = require('resx-json-typescript-converter');

const outputDir = path.resolve(__dirname, '../Prosjektmaler/Forskningsmal/Template');
const generatedFile = path.join(outputDir, 'Resources.json');
const targetFile = path.join(outputDir, 'Resources-research.json');

convertResx([
    path.resolve(__dirname, '../Prosjektmaler/Forskningsmal/Template/Resources.en-US.resx'),
    path.resolve(__dirname, '../Prosjektmaler/Forskningsmal/Template/Resources.no-NB.resx')
],
    outputDir,
    {
        defaultResxCulture: 'no-NB',
        mergeCulturesToSingleFile: true,
        generateTypeScriptResourceManager: false,
        searchRecursive: true,
    }
);

try {
    if (fs.existsSync(generatedFile)) {
        fs.renameSync(generatedFile, targetFile);
        console.log(`Success: Generated and renamed to ${path.basename(targetFile)}`);
    } else {
        console.warn('Warning: The expected Resources.json file was not found to rename.');
    }
} catch (error) {
    console.error('Error renaming file:', error);
}