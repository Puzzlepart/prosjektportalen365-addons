'use strict';

// check if gulp dist was called
if (process.argv.indexOf('dist') !== -1) {
    // add ship options to command call
    process.argv.push('--ship');
}

const gulp = require('gulp');
const build = require('@microsoft/sp-build-web');

build.addSuppression(`Warning - [sass] The local CSS class 'ms-Grid' is not camelCase and will not be type-safe.`);
build.addSuppression(`Warning - [sass] The local CSS class 'ms-DetailsHeader-cell' is not camelCase and will not be type-safe.`)
build.addSuppression(`Warning - [sass] src/projectOverview/components/ProjectOverview/ProjectOverview.scss: filename should end with module.sass or module.scss`)

/**
 * Custom Framework Specific gulp tasks
 */

build.tslintCmd.enabled = false;
build.initialize(gulp);
