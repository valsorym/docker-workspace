# SSH Docker project
# Doc: https://docs.docker.com/engine/examples/running_ssh_service/
FROM python:3.8.0-buster

# INSTALL
# Installation of additional utilities.
RUN apt-get update
RUN apt-get -y install wget

# REMOVE USER
# The some docker's image has user with 1000 UID already (for example `node`).
# This user must be removed.
RUN asshole=`grep '1000' /etc/passwd | cut -d\: -f1`; \
    [ -z "$asshole" ] && echo "..." || deluser --remove-home $asshole

# SUDO
# Allows users to run programs with the security privileges of another user,
# by default the superuser.
RUN mkdir -p /var/run/sshd /usr/local/project
RUN apt-get install -y sudo && \
    groupadd --gid 1000 code && \
    useradd --uid 1000 \
            --gid code \
            --shell /bin/bash \
            --create-home code && \
    usermod -a -G sudo code && \
    echo "code ALL=(ALL:ALL) NOPASSWD: ALL" > \
      /etc/sudoers.d/code

# SSHD
# The pam_loginuid - login fix (otherwise user is kicked off after login).
RUN apt-get install -y sudo openssh-server && \
    echo "code:code" | chpasswd && \
    echo "export VISIBLE=now" >> /etc/profile && \
    old_loginuid="session\s*required\s*pam_loginuid.so" && \
    new_loginuid="session optional pam_loginuid.so" && \
    sed "s@$old_loginuid@$loginuid@g" -i /etc/pam.d/sshd

# TMUX/LOCALE
# The multiplexer for Unix-like operating systems.
RUN apt-get install -y tmux locales && \
    sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && \
    locale-gen

USER code
RUN printf "%s\n" \
           "export LANGUAGE=en_US:en" \
           "export LC_ALL=en_US.UTF-8" \
           "export LANG=en_US.UTF-8" \
           "" >> /home/code/.profile

# PACKAGES
# Any tools.
USER root
RUN apt-get install -y vim

# GIT
# The distributed version-control system.
USER code
RUN sudo apt-get install -y git && \
    git config --global user.email "code@example.com" && \
    git config --global user.name "code"


# ARCHITECTURE
# Create project structure.
USER code
ENV HOME /home/code
ENV WORKSPACE ${HOME}/workspace
RUN mkdir -p ${WORKSPACE}
RUN echo "cd ${WORKSPACE} >& /dev/null" >> ${HOME}/.profile
WORKDIR /home/code/workspace

# ENTRYPOINT
# Launch entrypoint script.
USER root
RUN printf "%s\n" \
           "#!/bin/sh" \
           "[ \$# -gt 0 ] && eval \"\$@\"" \
           "exec /usr/sbin/sshd -D" \
           "" > /usr/local/project/docker-entrypoint.sh

COPY Dockerfile docker-entrypoint.* /usr/local/project/
RUN chmod +x /usr/local/project/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/project/docker-entrypoint.sh"]
