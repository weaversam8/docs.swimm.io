#!/usr/bin/env node
/** Copyright 2021 Swimm, Inc.
 * Tool to import release notes from Swimm's task & bug tracker (ClickUp, currently)
 * Not really useful to anyone else without modification, but it's easy enough to ship
 * in this repository. Requires configuration from environmental variables that aren't
 * included here.
 * 
 * License: MIT
 */

 "use strict"
const { SwimmReleases } = require('./scripts/swimm-releases.js'); 
const { Command, Option } = require('commander');
const program = new Command();
let fs = require('fs');
let YAML = require('yaml');

let Version = null;
let ReleaseContext = null;
let UseTheForce = false;

/* Option handlers */

function validateOption_versionName(option, prev) {
    let search = option.match(SwimmReleases.ValidVersionPattern());
    if (search == null) {
        console.error('Version name format must be one of: "0.1.2", "0.1.2u", "0.1.2.3", "0.1.2-3"');
        process.exit(1);
    }
    Version = option;
}

function validateOption_configFile(option, prev) {
    if (! fs.existsSync(option)) {
        console.error(`Invalid production config file location specified: ${option}`);
        process.exit(1);
    }
}

function validateOption_releaseConfig(option, prev) {
    if (! fs.existsSync(option)) {
        console.error(`Invalid release data config file location specified: ${option}`);
        process.exit(1);
    }
    let buffer = fs.readFileSync(option, 'utf8');
    ReleaseContext = YAML.parse(buffer);
}

function validateOption_stagger(option, prev) {
    console.log(option);
}

/* Metadata */

program
    .version('0.0.1', '-V, --version', 'print version information and exit normally.')
    .name("do")
    .description("The doer of release things that need done.")
    .usage("<global options> [arguments] <releasefile.yml>")
    .helpOption('-h, --help', 'read more information');

/* Global flags */

program
    .option('-c, --currentConfig [file.json]', 
        'production (current) releases configuration file location, if different than usual.', './releases.config.json', validateOption_configFile)
    .option('-C, --releaseConfig [file.yml]', 'pre-set values that will get passed to ReleaseFactory.', validateOption_releaseConfig)

/* Runtime Stuff */

program
    .option('-r, --release <name>', 
        'the Swimm version name, e.g. "0.1.2" or "0.1.2.3" or "0.1.2-3"', validateOption_versionName)
    .option('-f, --force', 
        'Import intermediate configs for all releases, even if in production.', false)
    .addOption(new Option('-m, --mode <mode>', 
        'function to perform.').choices([
            "init", 
            "import", 
            "export", 
            "draft", 
            "publish", 
            "refresh", 
            "backfill", 
            "backfill-notes", 
            "magic"
        ])
    );


program.parse();
const options = program.opts();
UseTheForce = options.force;

switch (options.mode) {
    /* Create the cache directory if needed, and initialize blank configs */
    case 'init':
        SwimmReleases.Init();
        console.log('You very likely now want to re-run with --mode=refresh');
        break;
    /* Import a release from a release config file (default is versionName.yml, e.g. 0.1.2.yml */
    case 'import':
        if (Version === null) {
            console.error('You must specify a --versionName to import. Did you mean "backfill"?');
            process.exit(1);
        }
        validateOption_releaseConfig(`./${Version}.yml`);
        console.log(ReleaseContext);
        SwimmReleases.Import(Version, ReleaseContext);
        break;
    /* Export YAML stringified live config object for a version. */
    case 'export':
        if (Version === null) {
            console.error('You must specify a --versionName to export.');
            process.exit(1);
        }
        SwimmReleases.Export(Version);
        break;
    /* Draft release notes for any unreleased versions we know about, as best as we can. */
    case 'draft':
        SwimmReleases.Drafts();
        break;
    /* Publish A Release Notes Draft */
    case 'publish':
        if (Version === null) {
            console.error('You must specify a --versionName to publish. There is no bulk publish feature, very deliberately.');
            process.exit(1);
        }
        break;
    /* Refresh the version cache */
    case 'refresh':
        SwimmReleases.Refresh();
        break;
    /* Backfill versions we don't yet have into the cache & write intermediate config with default values */
    case 'backfill':
        SwimmReleases.Backfill(UseTheForce);
       break;
    /* Backfill release notes for the imported versions */
    case 'backfill-notes':
        SwimmReleases.Notes();
        break;
    /* THIS MAGIC MOMENT .... */
    case 'magic':
        console.log(`It's a kind of magic ...`);
        SwimmReleases.Write();
        break;
    /* Commander shouldn't let us get here but famous last words and all */
    case undefined:
        console.error('Missing required option --mode, try --help for more.');
        process.exit(1);
    default:
        console.error(`Unknown option '${options.mode}' passed. Try --help mode'`);
        process.exit(1);
}
