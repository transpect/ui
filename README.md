# TranspectUI

## Outline

BaseX based UI for transpect converters. Currently uses BaseX 11.

### Functionalities:

* per converter UI definition
* localization support
* Worker/Frontend architecture
* Queuing
* User-Managment
* API

### Missing Features

* Post Conversion Actions

### Necessary Modifications to Conversion Makefiles
* `conversion` target definition must end with a colon (`:`)

### Running TranspectUI

`/` always refers to the root of the git clone

#### Create Controller/Worker Environment

##### Create Images

- Adding the converter code to `/code` and configuration to `/src/transpectui/converter.xml` (the image builder later scans `/transpect/infrastructure/ui` for a `configuration.xml`)
- Change admin password in `/.env`
- Create Converter Worker Docker Image via `/scripts/buildWorker.sh <converter-id>`. The name of the image wil be `transpectui_<converter-id>`. This dockerfile will look for a configuration.xml unter `/code/<converter-id>/transpect/infrastructure/ui` to use for the worker.
- Create Converter Frontend Docker Images via `/scripts/buildImages.sh`. The name if the image will be `transpectui`.

##### Define Services
- Add a service to the `docker/docker-compose.yml` (Check docker/docker-compose.yml.example for examples)

##### Launch
- Lauch the environment `docker compose create && docker compose start` inside `/docker` directory.
- Login via `http://localhost:8083/dba/login?_page=editor` with the above admin credentials. (These credentials are only for the BaseX access, not for TranspectUI)
- Set Admin-PW `import module namespace u = 'http://le-tex.de/user' at '/opt/basex/webapp/transpectui/user.xqm';
u:set-password('admin',<admin-password>)`
- Login to TranspectUI `http://localhost:8083/en/login`
- Create New Users `http://localhost:8083/en/users`

#### Running with mounted host volumes (For Testing Only) 

- download svn Repository to host `/code/<converter-id>`
- enter converter config in `/src/transpectui/converter.xml`
- use docker compose: `cd docker; docker compose up`
- access UI at [http://localhost:8083/en/converter](http://localhost:8083/en/converter)

- when config is done: `make start`

### Localization

- String Replacements are tracked in `/src/transpectui/i18n.xqm`
- Language flag images are placed under `/src/static/`. named like `en.png`