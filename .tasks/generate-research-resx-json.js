const path = require('path');
const fs = require('fs');
const { convertResx } = require('resx-json-typescript-converter');

// Define the output directory and filenames
const outputDir = path.resolve(__dirname, '../');
const generatedFile = path.join(outputDir, 'Resources.json');
const targetFile = path.join(outputDir, 'Resources-research.json');

// 1. Run the conversion (Generates Resources.json)
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

// 2. Rename the file to Resources-abc.json
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