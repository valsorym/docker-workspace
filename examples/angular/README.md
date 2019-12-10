# Angular2+ Example

Take a few steps to create your Angular2+ project.

1. Just create a workspace based on `NodeJS` distributive, for example: `node:13.3.0-buster`. 
2. Open the `docker-compose.yaml` and change `app`->`ports` section as:
```
    ...
    ports:
      - "2222:22"
      - "8800:4200"
    ...
```

3. Open the `Dockerfile` and the `RUN sudo npm install -g @angular/cli` into `ARCHITECTURE` section as:
```
# ARCHITECTURE
# Create project structure.
USER code
ENV HOME /home/code
ENV WORKSPACE ${HOME}/workspace
RUN mkdir -p ${WORKSPACE}
RUN sudo npm install -g @angular/cli
RUN echo "cd ${WORKSPACE} >& /dev/null" >> ${HOME}/.bash_profile
WORKDIR /home/code/workspace
```

4. Make build of the container:
`$ docker-compose build --no-cache`

5. Run the container and connect for it use SSH:
```
$ docker-compose up -d
$ ssh -p 2222 code@0.0.0.0
password: ***
```

6. Generate angular structure: `ng new` as:
```
% ng new --directory ./ --minimal --routing --skip-git \
         --style=scss --force basic
```
7. Open the `angular.json` and add host data `"host": "0.0.0.0"` into `serve`->`options` section as:
```
...
"serve": {
    "builder": "@angular-devkit/build-angular:dev-server",
    "options": {
        "browserTarget": "basic:build",
        "host": "0.0.0.0"
    },
    ...
...
```

8. Run project as `% ng serve` and open browser http://127.0.0.1:8800
