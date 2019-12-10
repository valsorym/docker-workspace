# DOCKER WORKSPACE SANDBOX

**Version:** 3.3.3

The docker environment workspace constructor. It is a special utility that is able to quickly create a docker environment based on any basic docker's images\*.  To the workspace can be accessed via SSH.

\* - *The images that are based on the Debian Linux only. When creating the workspace, a special user will be created and a number of additional utilities installed (for example: `tmux`, `vim`, `mc` etc.) using `aptitude` tools.*

P.s. See examples for angular2+, golang and python workspace in `examples/` directory.

## Quick start

### Work directory

Create and choose the workspace directory.

```
$ workspace="/path/to/your/workspace"
$ mkdir -p $workspace && cd $workspace
```

### Get the docker-workspace

Make clone of the `docker-workspace` and  take `docker-workspace.sh` script only\*.

```
$ cd /path/to/your/workspace/
$ rm -Rf /tmp/docker-workspace && \
  git clone git@github.com:valsorym/docker-workspace.git /tmp/docker-workspace && \
  cp /tmp/docker-workspace/docker-workspace.sh ./
```

### Make workspace

Use wizard mode as:
```
$ sh docker-workspace.sh
```

or create docker architecture use command-line\*\* mode, for example:

```
$ sh docker-workspace.sh python:3.7.2 workspace 2222
```

**P.s.** *Set the settings as you need: `BASE IMAGE`, `NETWORK NAME`, `SSH PORT` (see more `sh docker-workspace.sh --help`).*

\* - *The your project will have its own system files such as: `.git`, `.gitignore`, `.settings`, `README.md` - so, no need to inherit them from the docker-workspace project.*

\*\* - *The command-line mode allows you to automate the process of creating containers.*

\*\*\* - *You can run `sh docker-workspace.sh` only for use wizard mode.*

### Run

Make build the custom image and run it.

```
$ docker-compose build --no-cache
$ docker-compose up -d
```

**P.s.** *Ignore warnings like: `debconf: delaying package configuration, since apt-utils is not installed`. *

### Examples

#### Create python app

For example, create any python app in the current directory:

```
$ mkdir -p src
$ touch src/main.py
$ touch requirements.txt
...
```

#### SSH

Start SSH connection.

```
$ ssh -p 2222 code@0.0.0.0
```
**P.s.** *By default used password: `code`.*

**P.p.s.** *You can use `tmux` and `vim` in your docker's container.*

## FAQ
### What is the default user and password?

User `code` with password `code` was created in the container by default.

### How-to add PostgreSQL to the project?

Change the `docker-compose.yaml`:

```
version: '3.7'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    ports:
      - "2222:22"
    volumes:
      - .:/home/code/workspace
    networks:
      - workspace

  psql:
    image: postgres:10.1
    restart: always
    hostname: psql
    environment:
      - POSTGRES_USER=USERNAME
      - POSTGRES_DB=DATABASENAME
      - POSTGRES_PASSWORD=PASSWORD
    volumes:
      - ./psql/data:/var/lib/postgresql/data
      - ./psql/dump:/docker-entrypoint-initdb.d
    networks:
      - workspace

networks:
  workspace:
```

## How-to run additional commands at container start?

For example upgrade `pip` and install requirements.

Change the `docker-compose.yaml`:

```
version: '3.7'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    ports:
      - "2222:22"
    volumes:
      - .:/home/code/workspace
    command:
      - pip install --upgrade pip &&
      - pip install -r requirements.txt
    networks:
      - workspace

networks:
  workspace:
```

### How-to change base image?

Change the `Dockerfile`:

```
FROM python:3.7.2
...
```

**P.s.** *Change base image and re-build it as: `docker-compose build --no-cache`*.

# Requirements

## Dialog tools

You can use command-line mode and wizard mode to create docker workspace. To use wizard mode should be installed `whiptail` or `dialog`.

By default used the `whiptail` that  almost installed on all Linux distributions based on the Debian Linux. If the package is missing, you need to install it:

```
$ sudo apt-get -y install whiptail
```

Alternatively (if the `whiptail` package is missing) the `dialog` package can be used:

```
$ sudo apt-get -y install dialog
```

**P.s.** *You can simply run the `docker-workspace.sh` script and it will inform you about the problem (if the problem is exists).*

## Docker and docker-compose

### Install Docker

For Debian OS.

```
$ sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common && \
    sudo apt-get -y install docker.io && \
    docker --version && echo "Done!"
```

### Install docker-compose

```
$ url='https://github.com/docker/compose/releases/download/1.22.0/docker-compose' && \
    sudo bash -c "curl -L $url-`uname -s`-`uname -m` > /usr/local/bin/docker-compose" && \
    sudo chmod +x /usr/local/bin/docker-compose && \
    sudo ln -s /usr/local/bin/docker-compose /usr/local/bin/dc && \
    sudo docker-compose --version
```

### Allow to run docker without sudo

```
$ sudo apt-get -y install acl && \
    sudo gpasswd -a $USER docker && \
    sudo bash -c "setfacl -m user:$USER:rw /var/run/docker.sock" && \
    docker run hello-world
```
