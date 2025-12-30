// generate-project-templates.js

const fs = require('fs')
const path = require('path')
const pkg = require('../../package.json')
const { format } = require('util')
const { getFileContent } = require('./util')
const JsonTokenReplace = require('@ptkdev/json-token-replace')
const { replace } = new JsonTokenReplace()
const xml2js = require('xml2js')

// Parse resx files to create Resources.json
function parseResxFile(filePath) {
    const xmlContent = fs.readFileSync(filePath, 'utf-8')
    let result = {}
    
    xml2js.parseString(xmlContent, (err, parsed) => {
        if (err) {
            console.error(`Error parsing ${filePath}:`, err)
            return
        }
        
        if (parsed.root && parsed.root.data) {
            parsed.root.data.forEach(dataNode => {
                const name = dataNode.$.name
                const value = dataNode.value && dataNode.value[0] ? dataNode.value[0] : ''
                result[name] = value
            })
        }
    })
    
    return result
}

// Create RESOURCES_JSON from resx files
const RESOURCES_JSON = {
    'no-NB': parseResxFile(path.resolve(__dirname, '../Template/Resources.no-NB.resx')),
    'en-US': parseResxFile(path.resolve(__dirname, '../Template/Resources.en-US.resx'))
}

// Template names mapping
const templateNames = {
    'no-NB': {
        'Research': 'Forskningsmal'
    },
    'en-US': {
        'Research': 'ResearchTemplate'
    }
}

// Channel replace values (empty for now, add if needed)
const channelReplaceValues = {}

const JSON_MASTER_TEMPLATES_DIR = fs.readdirSync(path.resolve(__dirname, '../Template/JsonTemplates'))
const JSON_TEMPLATE_PREFIX = '_JsonTemplate'
const PROJECT_TEMPLATE_DIR = '../Template/Content/Portfolio_content.%s/ProjectTemplates/%s.txt'

// Ensure output directories exist
Object.keys(RESOURCES_JSON).forEach(lng => {
    const dir = path.resolve(__dirname, format('../Template/Content/Portfolio_content.%s/ProjectTemplates', lng))
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true })
    }
})

// For each JSON template, replace the tokens and write the output to the correct folder.
JSON_MASTER_TEMPLATES_DIR.forEach(templateFile => {
    const templateJson = getFileContent(`Template/JsonTemplates/${templateFile}`)
    const templateType = templateFile.substring(JSON_TEMPLATE_PREFIX.length).replace((/\.[^.]+/), '')
    const outputPaths = Object.keys(templateNames).reduce((acc, lng) => {
        acc[lng] = path.resolve(__dirname, format(PROJECT_TEMPLATE_DIR, lng, templateNames[lng][templateType]))
        return acc
    }, {})

    Object.keys(RESOURCES_JSON).forEach(lng => {
        const jsonTokens = { ...RESOURCES_JSON[lng], ...channelReplaceValues }
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

        console.log(`Generating ${outputPaths[lng]}`)
        
        fs.writeFileSync(
            outputPaths[lng],
            JSON.stringify(content, null, 4),
            'utf-8'
        )
    })
})