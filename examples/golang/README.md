# GoLang Example

Take a few steps to create your GoLang project.

1. Just create a workspace based on `Debian` distributive, for example: `debian:10.2`. 
2. Open the `docker-compose.yaml` and change `app`->`volumes` section as:
```
    ...
    volumes:
      - ./src:/home/code/workspace/src/app
    ...
```

3. Create the `src` directory and place the application's code there: 
`$ mkdir -p src/ && touch src/main.go`
P.s. Add some code into `src/main.go`.

4. Open the `Dockerfile` and change `ARCHITECTURE` section as:
```
# ARCHITECTURE
# Create project structure.
USER code
ENV HOME /home/code
ENV WORKSPACE ${HOME}/workspace
RUN mkdir -p ${WORKSPACE}

ENV GOVERSION 1.13.5
ENV GOPATH ${WORKSPACE}
RUN mkdir -p /tmp/golang && cd /tmp/golang && \
    wget https://dl.google.com/go/go${GOVERSION}.linux-amd64.tar.gz && \
    sudo tar -C /usr/local -xzf go${GOVERSION}.linux-amd64.tar.gz && \
    sudo ln -s /usr/local/go/bin/go /usr/bin/ && \
    mkdir -p ${GOPATH}/src/app ${GOPATH}/bin && \
    printf "%s\n" \
           "export INSTALL_DIRECTORY=${GOPATH}/bin" \
           "export GOPATH=${GOPATH}" \
           "export PATH=\$GOPATH/bin:/usr/local/go/bin:\$PATH"  \
           "cd ${GOPATH}/src/app >& /dev/null" >> ${HOME}/.bash_profile

RUN mkdir -p /tmp/godep && cd /tmp/godep && \
    wget https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    /bin/sh install.sh

WORKDIR ${GOPATH}/src/app
```

5. Make build of the container:
`$ docker-compose build --no-cache`

6. Run the container and connect for it use SSH:
```
$ docker-compose up -d
$ ssh -p 2222 code@0.0.0.0
password: ***
```

7. Run the code: `% go run main.go`.

P.s. Use [dep](https://github.com/golang/dep) to manage of the dependencies.
