#!/bin/sh

# DOCKER WORKSPACE
# A quick way to create a docker workspace with an SSH interface.
#
# Authors:
#   valsorym <valsorym.e@gmail.com>

# ACTUAL VERSION
__version__="3.3.3"

# CONSTANTS
# Special constants:
#   BUTTON_* - the constants for the dialog window's buttons.
BUTTON_OK=0
BUTTON_CANCEL=1
BUTTON_ESC=255

# Working directories:
SCRIPTNAME=`readlink -f "$0"`
DIRNAME=`dirname $SCRIPTNAME`
cd $DIRNAME

WORKDIR=`basename $DIRNAME`
BASEDIR=`pwd -P`

# Temporary files:
SCRIPTID=`echo "$SCRIPTNAME" | md5sum | sed 's# ##g' | cut -d\- -f1`
OUTBUFFER="/tmp/.${SCRIPTID}.OUTBUFFER"
_EXTERNAL_SETTINGS_PATH="/tmp/.${SCRIPTID}.DOCKER-WORKSPACE"
_LOCAL_SETTINGS_PATH="$BASEDIR/.docker-workspace"
if [ -s "$_LOCAL_SETTINGS_PATH" ]
then
  # Save settings in work directory.
  SETTINGS="$_LOCAL_SETTINGS_PATH"
else
  # Save settings temporarily.
  SETTINGS="$_EXTERNAL_SETTINGS_PATH"
fi

# CONTAINER OPTIONS:
# Set default values.
#   IMAGE - base image for new project;
#   PROJECT - project name;
#   SSHPORT - port to connect to the project using SSH;
#   USERNAME - the name of the main user in the project;
#   EMAIL - user e-mail (for git configuration);
#   PASSWORD - user's password;
#   DATABASES - supported databases (psql, mysql, redis);
#   PACKAGES - additional utilities (mc, vifm, htop);
#   ARCHITECTURE - additional files (docker-compose, entrypoint);
#   MAKEBUILD - "on" automatic build after saving.
_project=`printf "$WORKDIR" | sed 's/[^-\_0-9a-zA-Z]//g'`
[ -z "$1" ] && IMAGE="debian:10.2" || IMAGE="$1"
[ -z "$2" ] && PROJECT="$_project" || PROJECT="$2"
[ -z "$3" ] && SSHPORT="2222" || SSHPORT="$3"
[ -z "$4" ] && USERNAME="code" || USERNAME="$4"
[ -z "$5" ] && EMAIL="${USERNAME}@example.com" || EMAIL="$5"
[ -z "$6" ] && PASSWORD="code" || PASSWORD="$6"

DATABASES="" #"redis"
ARCHITECTURE="docker-compose.yaml" #"docker-compose.yaml docker-hotinit.sh"
PACKAGES="inotify-tools wget" # "htop"
MAKEBUILD="off"

# BACKTITLE
# ... for console
# ... for wizard
BACKTITLECONSOLE="DOCKER WORKSPACE"
BACKTITLEWIZARD="$BACKTITLECONSOLE v.$__version__"

# HELP TEXT
# ... for console
# ... for wizard
HELPCONSOLE="
A quick way to create a work project with an SSH interface.
Use from command line:
    --help  show this help information
    --clear clear temporary files and all project's system files

    IMAGE   run the script in non-blocking mode:
      sh docker-workspace.sh IMAGE [PROJECT [SSHPORT \
[USERNAME [EMAIL [PASSWORD]]]]]
      image     - base docker's image
      project - project name (network, database name, \
etc. default: $PROJECT)
      sshport   - host port for ssh (default: $SSHPORT)
      username  - user that will be created in the project \
(default: $USERNAME)
      email     - email for git configuration (default: $USEREMAIL)
      password  - ssh password (default: $PASSWORD)

Use like wizard:
    docker-workspace.sh"

HELPWIZARD="
A quick way to create a work project with an SSH interface.
Use the following parameters:\n
   *image - base docker's image
   *project - project name (network/database/image name)
   *sshport - host port for ssh
   *username - user that will be created in the project
   *email - email for git configuration
   *password - ssh password
   *packages - packages that will be installed in the image
   *databases - supported databases
   *architecture - project architecture"

# DISPLAY TYPE
# The 'whiptail' or 'dialog' package needed to run the wizard,
# but it is not necessary when script running with parameters.
if [ -z "$1" ]
then
  # WINDOW - type window (whiptail, dialog, Xdialog).
  WINDOW=whiptail
  is_exists=`whereis whiptail | cut -d\: -f2`
  if [ -z "$is_exists" ]
  then
    WINDOW=dialog
    is_exists=`whereis dialog | cut -d\: -f2`
    if [ -z "$is_exists" ]
    then
      printf "%s\n"                                                         \
        "$BACKTITLECONSOLE v.$__version__"                                  \
        "Wizard required the dependencies: whiptail, dialog"                \
        "You can use the command mode (see more, use --help)."
      exit 1
    fi # is exists dialog
  fi # is exists whiptail
elif [ "$1" = "help" ] || [ "$1" = "--help" ]
then
  printf "$HELPCONSOLE\n"
  exit 0
elif [ "$1" = "--clear" ]
then
  rm -Rf ./docker-compose.yaml ./docker-entrypoint.sh ./docker-hotinit.sh \
         ./Dockerfile $SETTINGS $OUTBUFFER
  exit 0
fi # wizard

# LOAD SAVED SETTINGS
# For wizard only.
if [ -z "$1" ] && [ -s "$SETTINGS" ]
then
  $WINDOW \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  SAVED SETTINGS  " \
    --yesno \
    "\nYou have already edited this project.\
     \nDo you want to load saved settings from the '$SETTINGS'?\
     \n\n** Select No for load default settings." \
     13 55

  cmd="$?"
  case $cmd in
    $BUTTON_OK)
      . "$SETTINGS"
      ;;
    $BUTTON_CANCEL) ;;
    $BUTTON_ESC) ;;
  esac
fi # load settings

# FUNCTIONS
# Management functions.
badvalue() {
  # Window shows information about bad value.
  #   text - main content;
  #   ignored - list of the ignored values.
  text=$1
  ignored=$2
  $WINDOW \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  WARNING  " \
    --msgbox "$text" \
    10 55
} # badvalue

changevalue() {
  # Change string value:
  #   title - title of the window;
  #   text - message in the window;
  #   target - the name of the global variable that should get the result;
  #   ignored - list of the ignore values.
  title=$1
  text="\n$2\n\n** Write the value and press Enter or Esc to exit."
  target=$3
  ignored=$4

  # Create window.
  eval "default=\$${target}"
  while true
  do
    if [ "$target" = "PASSWORD" ]
    then
      # Special password entry dialog.
      $WINDOW \
        --title "   $title   " \
        --clear \
        --backtitle "$BACKTITLEWIZARD" \
        --passwordbox "$text" \
        14 75 "" 2> $OUTBUFFER
    else
      # General dialogue.
      $WINDOW \
        --title "   $title   " \
        --clear \
        --backtitle "$BACKTITLEWIZARD" \
        --inputbox "$text" \
        14 75 "$default" 2> $OUTBUFFER
    fi # wintype

    cmd=$?
    value=`cat $OUTBUFFER`
    case $cmd in
      $BUTTON_OK)
        # Cannot set an empty value or values from the ignored list and..:
        # SSH Port.
        if [ "$target" = "SSHPORT" ]
        then
          case $value in
            ''|*[!0-9]*)
              badvalue "\nIncorrect \"$value\" value - it must be an integer.\
                        \nRecommend to set a number in the range: 2222-2299."
              continue
              ;;
            *) ;;
          esac
        fi # SSHPORT

        # Password.
        if [ "$target" = "PASSWORD" ]
        then
          length=`echo -n $value | wc -m`
          if [ $length -lt 3 ]
          then
            badvalue "\nToo short password.\
                      \nThe minimum password length is 3 characters."
            continue
          fi # length
        fi # PASSWORD

        # Ignored list.
        for ignore in $ignored
        do
          if [ "$value" = "$ignore" ]
          then
            badvalue "\nThe \"$value\" value is not valid.\
                      \nBad values: $ignored"
            default="$value"
            value=""
            break
          fi
        done

        # Re-enter if empty or ignored.
        if [ -z "$value" ]
        then
          continue
        else
          eval "${target}=\"$value\""
          break
        fi
        ;;
      $BUTTON_CANCEL) break ;;
      $BUTTON_ESC) break ;;
    esac
  done # while
} # changevalue

changepackages() {
  # Dialog for change additional tools.
  inotify_tools_status="off"
  wget_status="off"
  curl_status="off"
  unzip_status="off"
  vim_status="off"
  neovim_status="off"
  rcconf_status="off"
  vifm_status="off"
  mc_status="off"
  htop_status="off"
  for package in $PACKAGES
  do
    pkg=`echo "$package" | sed 's/-/_/g'`
    eval "${pkg}_status=\"on\""
  done

  $WINDOW \
    --clear \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  PACKAGES  " \
    --checklist \
    "\nYou can install additional tools in your project." \
    16 78 8 \
      "inotify-tools" \
        "Simple interface to inotify" \
        $inotify_tools_status \
      "rcconf" \
        "Debian Runlevel configuration tool" \
        $rcconf_status \
      "wget" \
        "Retrieves files from the web" \
        $wget_status \
      "curl" \
        "Tool for transferring data with URL syntax" \
        $curl_status \
      "unzip" \
        "De-archiver for .zip files" \
        $unzip_status \
      "vim" \
        "Vi IMproved - enhanced vi editor" \
        $vim_status \
      "neovim" \
        "Heavily refactored vim fork" \
        $neovim_status \
      "htop" \
        "Interactive processes viewer" \
        $htop_status \
      "vifm" \
        "The file manager with VI interface" \
        $vifm_status \
      "mc" \
        "The free cross-platform orthodox file manager    " \
        $mc_status \
    2> $OUTBUFFER

    cmd=$?
    value=`cat $OUTBUFFER`
    case $cmd in
      $BUTTON_OK) PACKAGES=`echo "$value" | sed 's/"//g'` ;;
      $BUTTON_CANCEL) ;;
      $BUTTON_ESC) ;;
    esac
} # changepackages

changedatabases() {
  # Dialog for change databases.
  # Available: psql, mysql, redis
  psql_status="off"
  mysql_status="off"
  redis_status="off"
  for item in $DATABASES
  do
    eval "${item}_status=\"on\""
  done

  $WINDOW \
    --clear \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  DATABASES  " \
    --checklist \
    "\nCreate additional docker environment management files."\
    16 78 8 \
      "redis" \
        "The open-source NoSQL database                           " \
        $redis_status \
      "psql" \
        "The open source ORDBMS" \
        $psql_status \
      "mysql" \
        "The open source RDBMS" \
        $mysql_status \
    2> $OUTBUFFER

    cmd=$?
    value=`cat $OUTBUFFER`
    case $cmd in
      $BUTTON_OK) DATABASES=`echo "$value" | sed 's/"//g'` ;;
      $BUTTON_CANCEL) ;;
      $BUTTON_ESC) ;;
    esac
} # changedatabases

changearchitect() {
  # Dialog for change architecture.
  # Available: docker-entrypoint.sh, docker-compose.yaml, docker-hotinit.sh
  docker_entrypoint_sh_status="off"
  docker_hotinit_sh_status="off"
  docker_compose_yaml_status="off"
  for item in $ARCHITECTURE
  do
    item=`echo "$item" | sed 's/[-\.]/_/g'`
    eval "${item}_status=\"on\""
  done

  $WINDOW \
    --clear \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  ARCHITECTURE  " \
    --checklist \
    "\nCreate additional docker environment management files."\
    16 78 8 \
      "docker-compose.yaml" \
        "Instructions for running docker-compose" \
        $docker_compose_yaml_status \
      "docker-hotinit.sh" \
        "Script for manual project init" \
        $docker_hotinit_sh_status \
      "docker-entrypoint.sh" \
        "Script runs after project activation      " \
        $docker_entrypoint_sh_status \
    2> $OUTBUFFER

    cmd=$?
    value=`cat $OUTBUFFER`
    case $cmd in
      $BUTTON_OK) ARCHITECTURE=`echo "$value" | sed 's/"//g'` ;;
      $BUTTON_CANCEL) ;;
      $BUTTON_ESC) ;;
    esac
} # changearchitect

helpwindow() {
  # Display help information.
  $WINDOW \
    --clear \
    --backtitle "$BACKTITLEWIZARD" \
    --title "  HELP  " \
    --msgbox "\n$HELPWIZARD" 21 75
} # helpwindow

progress() {
  # Show progress in progress bar.
  start=`expr "$1" - "3"`
  end=`expr "$1" + "3"`
  result=`shuf -i $start-$end -n 1`
  echo $result

  # Force sleep.
  dealy=`shuf -i 5-9 -n 1`
  sleep "0.0$dealy"
} # progress

main() {
  # Main window.
  while true
  do
    # Hide password for asterisks.
    _password=`echo "$PASSWORD" | \
              awk '{print substr($0,0,1) "***" substr($0,length)}'`

    # Short architecture list.
    _architecture="$ARCHITECTURE"
    _architecture_len=`echo "$ARCHITECTURE" | wc -m`
    if [ $_architecture_len -gt 45 ]
    then
      _architecture=`echo "$ARCHITECTURE" | cut -c 1-45`
      _architecture="$_architecture..."
    fi # architecture

    # Draw window.
    $WINDOW \
      --clear \
      --backtitle "$BACKTITLEWIZARD" \
      --title "  MAIN OPTIONS   " \
      --menu "\nThe main docker's environment settings.\n\
              \n** Use the UP/DOWN arrow keys or first letter of the \
              \n   choice to choose an option. Press Esc to help." \
      24 78 12 \
        "1" "Image:        $IMAGE" \
        "2" "Project:      $PROJECT" \
        "3" "SSH Port:     $SSHPORT" \
        "4" "Username:     $USERNAME" \
        "5" "E-mail:       $EMAIL" \
        "6" "Password:     $_password" \
        "7" "Packages:     $PACKAGES" \
        "8" "Databases:    $DATABASES" \
        "9" "Architecture: $_architecture" \
        "" "                                                                " \
        "s" "Save and exit" \
        "b" "Save and build" \
      2> $OUTBUFFER

    cmd=$?
    value=`cat $OUTBUFFER`
    case $cmd in
      $BUTTON_OK)
        MAKEBUILD="off"
        [ "$value" = "b" ] && value="s" && MAKEBUILD="on"
        case $value in
          1)
            changevalue \
              "CHANGE BASIC DOCKER IMAGE" \
              "Based on the Linux Debian distribution only.\
               \nSee here: https://hub.docker.com" "IMAGE"
            ;;
          2)
            changevalue \
              "CHANGE PROJECT NAME" \
              "Project name (by default it will be set for: virtual \
               network name, database name, image name etc.)." "PROJECT"
              PROJECT=`printf "$PROJECT" | sed 's/[^-\_0-9a-zA-Z]//g'`
            ;;
          3)
            changevalue \
              "CHANGE SSH PORT" \
              "Set a port for the SSH connection." "SSHPORT"
            ;;
          4)
            changevalue \
              "CHANGE USERNAME" \
              "In the project will be created new user, whose behalf \
               the project will be managed. And this username will be used \
               to configure git by default." "USERNAME" "root admin"
            ;;
          5)
            changevalue \
              "CHANGE E-MAIL" \
              "This e-mail will be used to configure git by default." "EMAIL"
            ;;
          6)
            changevalue \
              "CHANGE PASSWORD" \
              "Enter a new user password (the password will not be \
               displayed on the screen)." "PASSWORD"
            ;;
          7)
            changepackages
            continue
            ;;
          8)
            changedatabases
            continue
            ;;
          9)
            changearchitect
            continue
            ;;
          "s")
            # Short information about "architecture".
            _architecture=""
            for item in $ARCHITECTURE
            do
              _architecture="$_architecture\n        + $item"
            done
            [ ! -z "$_architecture" ] && \
              _architecture="\n    Architecture:$_architecture"

            # Short information about "tools".
            _tools=""
            for item in $PACKAGES
            do
              _tools="$_tools\n        + $item"
            done
            [ ! -z "$_tools" ] && \
              _tools="\n    Tools:$_tools"

            # Build status.
            _build=""
            if [ "$MAKEBUILD" = "on" ]
            then
              _build="\n\n  ** At the end will be launched docker build! **"
            fi

            # Complete dialog.
            $WINDOW \
              --backtitle "$BACKTITLEWIZARD" \
              --title "  FINISH  " \
              --defaultno \
              --yesno \
              "\nDo you want to save these settings in the project?\
              * Esc - to cancel (back to the main menu);\
              * Yes - save settings in the project directory;\
              * No - save settings in a temporary directory.\n\
              \n    Image: $IMAGE\
              \n    project: $PROJECT\
              \n    SSH port: $SSHPORT\
              \n    Username: $USERNAME\
              \n    E-mail: $USERNAME\
              $_architecture $_tools $_build\n" 25 55

            cmd="$?"
            case $cmd in
              $BUTTON_OK)
                SETTINGS="$_LOCAL_SETTINGS_PATH"
                rm -Rf "$_EXTERNAL_SETTINGS_PATH"
                break
                ;;
              $BUTTON_CANCEL)
                SETTINGS="$_EXTERNAL_SETTINGS_PATH"
                rm -Rf "$_LOCAL_SETTINGS_PATH"
                break
                ;;
              $BUTTON_ESC) continue ;;
            esac
        esac
        ;;
      $BUTTON_CANCEL)
        clear
        exit 0
        ;;
      $BUTTON_ESC)
        helpwindow
        continue
        ;;
    esac
  done
} # main

# DISPLAY MENU ############################################################# #
##############################################################################
if [ -z "$1" ]
then
  # WIZARD MODE
  # Show main dialog.
  main

  # REPLACE SYSTEM FILES
  # Protection against deleting existing files.
  docker_entrypoint_sh_status="off"
  docker_hotinit_sh_status="off"
  docker_compose_yaml_status="off"
  for item in $ARCHITECTURE
  do
    cmd=$BUTTON_OK
    if [ -s "$item" ]
    then
      $WINDOW \
        --backtitle "$BACKTITLEWIZARD" \
        --defaultno \
        --title "  WARNING  " \
        --yesno \
        "\nThe \"$item\" file already exists, replace it?" 10 70

      cmd="$?"
    fi

    case $cmd in
      $BUTTON_OK)
        item=`echo "$item" | sed 's/[-\.]/_/g'`
        eval "${item}_status=on"
        continue
        ;;
      $BUTTON_CANCEL) continue ;;
      $BUTTON_ESC) continue ;;
    esac
  done

  # Clear all.
  clear
else
  # CONSOLE MODE
  # Create architect files:
  docker_compose_yaml_status="on"
  docker_hotinit_sh_status="on"
  printf "%s\n"                                                             \
    "$BACKTITLECONSOLE v.$__version__"                                      \
    ""                                                                      \
    "  Image: $IMAGE"                                                       \
    "  project: $PROJECT"                                                   \
    "  SSH port: $SSHPORT"                                                  \
    "  Username: $USERNAME"                                                 \
    "  E-mail: $EMAIL"                                                      \
    "  Password: $PASSWORD"                                                 \
    "  Databases: $DATABASES"                                               \
    "  Architecture: $ARCHITECTURE"                                         \
    "  Tools: $PACKAGES"                                                    \
    ""
fi # not command mode

# FILE MANAGEMENT ########################################################## #
##############################################################################
{
# TEMPORARY SETTINGS
# Settings are saved in a temporary file for the ability to correct
# the workspace settings (only for wizard mode).
# ============================================================================
[ -z "$1" ] && cat <<EOF >$SETTINGS
IMAGE="$IMAGE"
PROJECT="$PROJECT"
SSHPORT="$SSHPORT"
USERNAME="$USERNAME"
EMAIL="$EMAIL"
PASSWORD="$PASSWORD"
DATABASES="$DATABASES"
ARCHITECTURE="$ARCHITECTURE"
PACKAGES="$PACKAGES"
EOF
progress 10

# DOCKERFILE
# Docker's image configuration file.
# ============================================================================
# Create and change Dockerfile file.
_file="./Dockerfile.template"
cat <<"EOF" >$_file
# SSH Docker project
# Doc: https://docs.docker.com/engine/examples/running_ssh_service/
FROM %%IMAGE%%

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
    groupadd --gid 1000 %%USERNAME%% && \
    useradd --uid 1000 \
            --gid %%USERNAME%% \
            --shell /bin/bash \
            --create-home %%USERNAME%% && \
    usermod -a -G sudo %%USERNAME%% && \
    echo "%%USERNAME%% ALL=(ALL:ALL) NOPASSWD: ALL" > \
      /etc/sudoers.d/%%USERNAME%%

# SSHD
# The pam_loginuid - login fix (otherwise user is kicked off after login).
RUN apt-get -y install openssh-server && \
    echo "%%USERNAME%%:%%PASSWORD%%" | chpasswd && \
    echo "export VISIBLE=now" >> /etc/profile && \
    old_loginuid="session\s*required\s*pam_loginuid.so" && \
    new_loginuid="session optional pam_loginuid.so" && \
    sed "s@$old_loginuid@$loginuid@g" -i /etc/pam.d/sshd

# PACKAGES
# Any tools.
USER root
RUN apt-get -y install %%PACKAGES%%

# LOCALE SETTINGS
# Set en_US.UTF-8 as default. 
USER root
RUN sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && \
    locale-gen

USER %%USERNAME%%
RUN printf "%s\n" \
           "export LANGUAGE=en_US:en" \
           "export LC_ALL=en_US.UTF-8" \
           "export LANG=en_US.UTF-8" \
           "" >> /home/%%USERNAME%%/.profile

# ARCHITECTURE
# Create structure of the workspace.
USER %%USERNAME%%
ENV HOME /home/%%USERNAME%%
ENV WORKSPACE ${HOME}/workspace
RUN mkdir -p ${WORKSPACE}
RUN echo "cd ${WORKSPACE} >& /dev/null" >> ${HOME}/.profile
WORKDIR ${WORKSPACE}

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
EOF
progress 20

# Change Dockerfile parameters.
# Add `locales` package as required.
[ -z "$PACKAGES" ] && PACKAGES="locales" || PACKAGES="locales $PACKAGES"
sed                                                                         \
    -e 's#%%IMAGE%%#'"$IMAGE"'#g;'                                          \
    -e 's#%%USERNAME%%#'"$USERNAME"'#g;'                                    \
    -e 's#%%EMAIL%%#'"$EMAIL"'#g;'                                          \
    -e 's#%%PASSWORD%%#'"$PASSWORD"'#g;'                                    \
    -e 's#%%PACKAGES%%#'"$PACKAGES"'#g;'                                    \
    ./Dockerfile.template > Dockerfile &&                                   \
    rm -f ./Dockerfile.template
progress 30

# DOCKER-COMPOSE
# Configuration file for docker-compose utility.
# ============================================================================
# Create and change docker-compose.yaml.
_file="./docker-compose.yaml.template"
[ "$docker_compose_yaml_status" = "on" ] && cat <<"EOF" >$_file
version: '3.7'

services:
  app:
    image: workspace/%%IMAGE%%-%%PROJECT%%
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
#:command:#    command:
#:command:#      - /bin/sh docker-hotinit.sh
    ports:
      - "%%SSHPORT%%:22"
    volumes:
      - .:/home/%%USERNAME%%/workspace
#:depends_on:#    depends_on:
#:redis:#      - redis
#:mysql:#      - mysql
#:psql:#      - psql
    networks:
      - %%PROJECT%%
#:redis:#
#:redis:#  redis:
#:redis:#    image: redis:latest
#:redis:#    restart: always
#:redis:#    hostname: redis
#:redis:#    networks:
#:redis:#      %%PROJECT%%:
#:redis:#        aliases:
#:redis:#          - redis
#:mysql:#
#:mysql:#  mysql:
#:mysql:#    image: mysql:5.7
#:mysql:#    restart: always
#:mysql:#    hostname: mysql
#:mysql:#    environment:
#:mysql:#      - MYSQL_USER=%%USERNAME%%
#:mysql:#      - MYSQL_DATABASE=%%PROJECT%%
#:mysql:#      - MYSQL_PASSWORD=%%PASSWORD%%
#:mysql:#      - MYSQL_ROOT_PASSWORD=%%PASSWORD%%
#:mysql:#    volumes:
#:mysql:#      - ./db/mysql/data:/var/lib/mysql
#:mysql:#      - ./db/mysql/dump:/docker-entrypoint-initdb.d
#:mysql:#    networks:
#:mysql:#      %%PROJECT%%:
#:mysql:#        aliases:
#:mysql:#          - mysql
#:psql:#
#:psql:#  psql:
#:psql:#    image: postgres:10.1
#:psql:#    restart: always
#:psql:#    hostname: psql
#:psql:#    environment:
#:psql:#      - POSTGRES_USER=%%USERNAME%%
#:psql:#      - POSTGRES_DB=%%PROJECT%%
#:psql:#      - POSTGRES_PASSWORD=%%PASSWORD%%
#:psql:#    volumes:
#:psql:#      - ./db/psql/data:/var/lib/psql/data
#:psql:#      - ./db/psql/dump:/docker-entrypoint-initdb.d
#:psql:#    networks:
#:psql:#      %%PROJECT%%:
#:psql:#        aliases:
#:psql:#          - psql

networks:
  %%PROJECT%%:
EOF
progress 50

if [ "$docker_compose_yaml_status" = "on" ]
then
  # Add Db support.
  _depends_on=""
  for item in $DATABASES
  do
    _depends_on="depends_on"
    eval "_${item}=\"${item}\""
  done # _redis, _mysql, _postgres

  # Update docker-compose.yaml.
  [ "$docker_hotinit_sh_status" = "on" ] && _command="command" || _command=""
  sed                                                                       \
      -e 's#%%IMAGE%%#'"$IMAGE"'#g;'                                        \
      -e 's#%%PROJECT%%#'"$PROJECT"'#g;'                                    \
      -e 's#%%USERNAME%%#'"$USERNAME"'#g;'                                  \
      -e 's#%%PASSWORD%%#'"$PASSWORD"'#g;'                                  \
      -e 's#%%SSHPORT%%#'"$SSHPORT"'#g;'                                    \
      -e 's/#:'"$_depends_on"':#//g;'                                       \
      -e 's/#:'"$_command"':#//g;'                                          \
      -e 's/#:'"$_redis"':#//g;'                                            \
      -e 's/#:'"$_mysql"':#//g;'                                            \
      -e 's/#:'"$_psql"':#//g;'                                             \
      -e '/#:/ d'                                                           \
      ./docker-compose.yaml.template > ./docker-compose.yaml &&             \
      rm -f ./docker-compose.yaml.template

  # Create psql data folder.
  if [ ! -z "$_psql" ]
  then
    mkdir -p ./db/psql/data ./db/psql/dump
    printf "%s\n"                                                           \
      "CREATE USER \"$USERNAME\" WITH PASSWORD \"$PASSWORD\";"              \
      "DROP DATABASE IF EXISTS $PROJECT;"                                   \
      "CREATE DATABASE $PROJECT;"                                           \
      "GRANT ALL PRIVILEGES ON DATABASE $PROJECT TO $USERNAME;"             \
      "" > ./db/psql/dump/init.sql.example
  fi # _psql

  # Create mysql data folder.
  if [ ! -z "$_mysql" ]
  then
    mkdir -p ./db/mysql/data ./db/mysql/dump
    host="$USERNAME@localhost"
    character="CHARACTER SET utf8 COLLATE utf8_general_ci"
    printf "%s\n"                                                           \
      "DROP DATABASE IF EXISTS $PROJECT;"                                   \
      "CREATE DATABASE $PROJECT $character;"                                \
      "GRANT ALL ON $PROJECT.* TO $host IDENTIFIED BY '$PASSWORD';"         \
      "FLUSH PRIVILEGES;"                                                   \
      "" > ./db/psql/mysql/init.sql.example
  fi # _mysql
fi # docker-compose.yaml
progress 60

# ENTRYPOINT
# The script that runs after the start of the project and blocks the
# execution of the main thread.
# ============================================================================
# Create docker-entrypoint.sh.
_file="./docker-entrypoint.sh"
[ "$docker_entrypoint_sh_status" = "on" ] && cat <<"EOF" >$_file
#!/bin/sh

[ $# -gt 0 ] && eval "$@"
exec /usr/sbin/sshd -D
EOF
progress 85

# HOTINIT
# The special non-blocking script that runs immediately after the project is
# started (not to be confused with the entrypoint). Designed for quick testing
# of tasks that should be included in the production image.
# ============================================================================
# Create docker-hotinit.sh.
_file="./docker-hotinit.sh"
[ "$docker_hotinit_sh_status" = "on" ] && cat <<"EOF" >$_file
#!/bin/sh

# Write your code here, for example:
# [ -s "./requirements.txt" ] && \
#   sudo pip install -r ./requirements.txt

exit 0
EOF
progress 90
} | {
  [ -z "$1" ] && whiptail --title "  SAVE  " --gauge  "Please wait ..." 6 50 0
}

# BUILD
# Run build of the docker's image, like: docker-compose build --no-cache
# ============================================================================
[ "$MAKEBUILD" = "on" ] && docker-compose build --no-cache

exit 0
