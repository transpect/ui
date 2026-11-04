# TranspectUI

## Outline

BaseX based UI for transpect converters. Currently uses BaseX 13.

### Functionalities:

* per converter UI definition
* per converter file duplication limits
* localization support
* Worker/Frontend architecture
* Queuing
* User-Managment
* API
* Global Queue

### Missing Features

* Post Conversion Actions

### Running TranspectUI

`/` always refers to the root of the git clone

#### Create Controller/Worker Environment

##### Create Images

- Change admin password in `/.env`
- Build worker-images (usually 1 converter per worker) via `scripts/buildWorker.sh`. The Dockerfile in the background copies transpect/infrastruture/ui/converter.xml into the Image.
- Example: `./buildWorker.sh <id> <svnurl> <revision> <svnuser> <svnpw>`
- Create Converter Frontend Docker Images via `/scripts/buildUI.sh`. The name of the image will be `transpectui`.

##### Define Services
- Add a service to the `docker/docker-compose.yml` (Check docker/docker-compose.yml.template for examples)

##### Launch
- Lauch the environment `docker compose create && docker compose start` inside `/docker` directory. (`make start`)
- Login via `http://localhost:8083/dba/login?_page=editor` with the above admin credentials. (These credentials are only for the BaseX access, not for TranspectUI)
- Set Admin-PW: `import module namespace u = 'http://le-tex.de/user'; u:set-password('admin',<admin-password>)`
- Login to TranspectUI `http://localhost:8083/en/login`
- Create new users `http://localhost:8083/en/users`
- Stop the environment `make stop`. It also removes all created containers. The conversion results are stored under /data/<worker>/

### Localization
- String Replacements are tracked in `/src/transpectui/i18n.xqm`

### AI Disclamer
Parts of this code is created by AI. Every Commit is reviewed by humans.