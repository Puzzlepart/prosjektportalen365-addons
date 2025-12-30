// generate-project-templates.js

const fs = require('fs')
const path = require('path')
const pkg = require('../package.json')
const { format } = require('util')
const { getFileContent } = require('./util')
const JsonTokenReplace = require('@ptkdev/json-token-replace')
const { replace } = new JsonTokenReplace()

// Template names for the different languages
const templateNames = {
    'no-NB': {
        'Research': 'Forskningsmal'
    },
    'en-US': {
        'Research': 'Researchtemplate'
    }
}

const RESOURCES_JSON = getFileContent('Prosjektmaler/Forskningsmal/Template/Resources-research.json')
const JSON_MASTER_TEMPLATES_DIR = fs.readdirSync(path.resolve(__dirname, '../Prosjektmaler/Forskningsmal/Template/JsonTemplates'))
const JSON_TEMPLATE_PREFIX = '_JsonTemplate'
const PROJECT_TEMPLATE_DIR = '../Prosjektmaler/Forskningsmal/ProjectExtensions/%s.txt'

// For each JSON template, replace the tokens and write the output to the correct folder.
JSON_MASTER_TEMPLATES_DIR.forEach(templateFile => {
    const templatePath = `Prosjektmaler/Forskningsmal/Template/JsonTemplates/${templateFile}`
    const templateJson = getFileContent(templatePath)
    const templateType = templateFile.substring(JSON_TEMPLATE_PREFIX.length).replace((/\.[^.]+/), '')
    
    const outputPaths = Object.keys(templateNames).reduce((acc, lng) => {
        acc[lng] = path.resolve(__dirname, format(PROJECT_TEMPLATE_DIR, lng, templateNames[lng][templateType]))
        return acc
    }, {})

    Object.keys(RESOURCES_JSON).forEach(lng => {
        const jsonTokens = RESOURCES_JSON[lng]
        
        let content = replace(
            jsonTokens,
            templateJson,
            '{{',
            '}}'
        )

        content = replace(
            pkg,
            content,
            '{',
            '}'
        )

        const outputPath = outputPaths[lng]
        
        // Ensure directory exists
        const outputDir = path.dirname(outputPath)
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true })
        }
        
        fs.writeFile(
            outputPath,
            JSON.stringify(content, null, 4),
            (err) => {
                if (err) {
                    console.error(`Error writing ${outputPath}:`, err)
                }
            })
    })
})