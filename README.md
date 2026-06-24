# TranspectUI

## Outline

BaseX based UI for transpect converters. Currently uses BaseX 11.

### Functions:

* per converter UI definition
* localization support

### Missing Features

* Post Conversion Actions

### Necessary Modifications to Conversion Makefiles
* `conversion` target definition must end with a colon (`:`)
* add line `echo $$PPID > $(IN_FILE).pid` as first command in conversion target

### Running TranspectUI

`/` always refers to the root of the git clone

#### Create Image for isolated Docker Deployment

- Adding the converter code to `/code` and configuration to `/src/transpectui/converter.xml`
- Change admin password in `/.env`
- Create docker image with `/scripts/buildDist.sh`
- docker image name: `transpectuidist`
- Port 8000, HTTP only

#### Running with mounted host volumes (For Testing Only) 

- download svn Repository to host `/code/#converter-id#`
- enter converter config in `/src/transpectui/converter.xml`
- use docker compose: `cd docker; docker compose up`
- access UI at [http://localhost:8083/en/converter](http://localhost:8083/en/converter)

- when config is done: `make start`

### Localization

- String Replacements are tracked in `/src/transpectui/i18n.xqm`
- Language flag images are placed under `/src/static/`. named like `en.png`