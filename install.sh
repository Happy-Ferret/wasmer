#!/bin/sh

# This install script is intended to download and install the latest available
# release of the wasmer.
# Installer script inspired from:
#  1) https://raw.githubusercontent.com/golang/dep/master/install.sh
#  2) https://sh.rustup.rs
#  3) https://yarnpkg.com/install.sh
#  4) https://raw.githubusercontent.com/brainsik/virtualenv-burrito/master/virtualenv-burrito.sh
#
# It attempts to identify the current platform and an error will be thrown if
# the platform is not supported.
#
# Environment variables:
# - INSTALL_DIRECTORY (optional): defaults to $HOME/.wasmer
# - WASMER_RELEASE_TAG (optional): defaults to fetching the latest release
# - WASMER_OS (optional): use a specific value for OS (mostly for testing)
# - WASMER_ARCH (optional): use a specific value for ARCH (mostly for testing)
#
# You can install using this script:
# $ curl https://raw.githubusercontent.com/WAFoundation/wasmer/master/install.sh | sh

set -e


reset="\033[0m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
cyan="\033[36m"
white="\033[37m"

RELEASES_URL="https://github.com/WAFoundation/wasmer/releases"

wasmer_download_json() {
    url="$2"

    # echo "Fetching $url.."
    if test -x "$(command -v curl)"; then
        response=$(curl -s -L -w 'HTTPSTATUS:%{http_code}' -H 'Accept: application/json' "$url")
        body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
        code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    elif test -x "$(command -v wget)"; then
        temp=$(mktemp)
        body=$(wget -q --header='Accept: application/json' -O - --server-response "$url" 2> "$temp")
        code=$(awk '/^  HTTP/{print $2}' < "$temp" | tail -1)
        rm "$temp"
    else
        printf "$red> Neither curl nor wget was available to perform http requests.$reset\n"
        exit 1
    fi
    if [ "$code" != 200 ]; then
        printf "$red>File download failed with code $code.$reset\n"
        exit 1
    fi

    eval "$1='$body'"
}

wasmer_download_file() {
    url="$1"
    destination="$2"

    # echo "Fetching $url.."
    if test -x "$(command -v curl)"; then
        code=$(curl --progress-bar -w '%{http_code}' -L "$url" -o "$destination")
    elif test -x "$(command -v wget)"; then
        code=$(wget --show-progress --progress=bar:force:noscroll -q -O "$destination" --server-response "$url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -1)
    else
        printf "$red> Neither curl nor wget was available to perform http requests.$reset\n"
        exit 1
    fi

    if [ "$code" == 404 ]; then
        printf "$red> Your architecture is not yet supported ($OS-$ARCH).$reset\n"
        echo "> Please open an issue on the project if you would like to use wasmer in your project: https://github.com/WAFoundation/wasmer"
        exit 1
    elif [ "$code" != 200 ]; then
        printf "$red>File download failed with code $code.$reset\n"
        exit 1
    fi
}


wasmer_detect_profile() {
  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''
  local SHELLTYPE
  SHELLTYPE="$(basename "/$SHELL")"

  if [ "$SHELLTYPE" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "$SHELLTYPE" = "zsh" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  elif [ "$SHELLTYPE" = "fish" ]; then
    DETECTED_PROFILE="$HOME/.config/fish/config.fish"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    if [ -f "$HOME/.profile" ]; then
      DETECTED_PROFILE="$HOME/.profile"
    elif [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.config/fish/config.fish" ]; then
      DETECTED_PROFILE="$HOME/.config/fish/config.fish"
    fi
  fi

  if [ ! -z "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

wasmer_link() {
  printf "$cyan> Adding to \$PATH...$reset\n"
  WASMER_PROFILE="$(wasmer_detect_profile)"
  SOURCE_STR="\nexport PATH=\"\$HOME/.wasmer/bin:\$PATH\"\n"

  if [ -z "${WASMER_PROFILE-}" ] ; then
    printf "$red> Profile not found. Tried ${WASMER_PROFILE} (as defined in \$PROFILE), ~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile.\n"
    echo "> Create one of them and run this script again"
    echo "> Create it (touch ${WASMER_PROFILE}) and run this script again"
    echo "   OR"
    printf "> Append the following lines to the correct file yourself:$reset\n"
    command printf "${SOURCE_STR}"
  else
    if ! grep -q 'wasmer' "$WASMER_PROFILE"; then
      if [[ $WASMER_PROFILE == *"fish"* ]]; then
        command fish -c 'set -U fish_user_paths $fish_user_paths ~/.wasmer/bin'
      else
        command printf "$SOURCE_STR" >> "$WASMER_PROFILE"
      fi
    fi

    printf "$cyan> We've added the following to your $WASMER_PROFILE\n"
    echo "> If this isn't the profile of your current shell then please add the following to your correct profile:"
    printf "   $SOURCE_STR$reset\n"

    version=`$HOME/.wasmer/bin/wasmer --version` || (
      printf "$red> Wasmer was installed, but doesn't seem to be working :(.$reset\n"
      exit 1;
    )

    printf "$green> Successfully installed Wasmer $version! Please open another terminal where the \`wasmer\` command will now be available.$reset\n"
  fi
}


# findWasmerBinDirectory() {
#     EFFECTIVE_WASMERPATH=$(wasmer env WASMERPATH)
#     if [ -z "$EFFECTIVE_WASMERPATH" ]; then
#         echo "Installation could not determine your \$WASMERPATH."
#         exit 1
#     fi
#     if [ -z "$WASMERBIN" ]; then
#         WASMERBIN=$(echo "${EFFECTIVE_WASMERPATH%%:*}/bin" | sed s#//*#/#g)
#     fi
#     if [ ! -d "$WASMERBIN" ]; then
#         echo "Installation requires your WASMERBIN directory $WASMERBIN to exist. Please create it."
#         exit 1
#     fi
#     eval "$1='$WASMERBIN'"
# }

initArch() {
    ARCH=$(uname -m)
    if [ -n "$WASMER_ARCH" ]; then
        printf "$cyan> Using WASMER_ARCH ($WASMER_ARCH).$reset\n"
        ARCH="$WASMER_ARCH"
    fi
    case $ARCH in
        amd64) ARCH="amd64";;
        x86_64) ARCH="amd64";;
        # i386) ARCH="386";;
        *) printf "$red> The system architecture (${ARCH}) is not supported by this installation script.$reset\n"; exit 1;;
    esac
    # echo "ARCH = $ARCH"
}

initOS() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    if [ -n "$WASMER_OS" ]; then
        printf "$cyan> Using WASMER_OS ($WASMER_OS).$reset\n"
        OS="$WASMER_OS"
    fi
    case "$OS" in
        darwin) OS='darwin';;
        linux) OS='linux';;
        freebsd) OS='freebsd';;
        # mingw*) OS='windows';;
        # msys*) OS='windows';;
        *) printf "$red> The OS (${OS}) is not supported by this installation script.$reset\n"; exit 1;;
    esac
    # echo "OS = $OS"
}


# unset profile
# test -z "$exclude_profile" && modify_profile
# if [ -n "$profile" ]; then
#     if [ -e $HOME/${profile}.pre-wasmer ]; then
#         backup=" The original\nwas saved to ~/$profile.pre-wasmer."
#     fi
# fi

# source $WASMERPATH/startup.sh

wasmer_install() {
  magenta1="${reset}\033[34;1m"
  magenta2="${reset}\033[34m"
  magenta3="${reset}\033[34;2m"

  printf "${white}Installing Wasmer!$reset\n"
  printf "
 ${magenta1}      ${magenta2}        ${magenta3}###${reset}                                 
 ${magenta1}      ${magenta2}        ${magenta3}#####${reset}                               
 ${magenta1}      ${magenta2}###     ${magenta3}######${reset}                   
 ${magenta1}      ${magenta2}######  ${magenta3}#############${reset}            
 ${magenta1}#     ${magenta2}####### ${magenta3}##############${reset}
 ${magenta1}##### ${magenta2}#############${magenta3}#########${reset}
 ${magenta1}######${magenta2}###############${magenta3}#######${reset}
 ${magenta1}############${magenta2}#########${magenta3}#######${reset}
 ${magenta1}##############${magenta2}#######${magenta3}#######${reset}
 ${magenta1}##############${magenta2}#######${magenta3}#######${reset}
 ${magenta1}##############${magenta2}#######${magenta3}#######${reset}
 ${magenta1}##############${magenta2}#######${magenta3}    ###${reset}
 ${magenta1}##############${magenta2}#######                          
    ${magenta1}###########${magenta2}    ###                          
       ${magenta1}########${magenta2}                                 
           ${magenta1}####${reset}                                    

"
#   if [ -d "$HOME/.wasmer" ]; then
#     if which wasmer; then
#       local latest_url
#       local specified_version
#       local version_type
#       if [ "$1" = '--nightly' ]; then
#         latest_url=https://nightly.wasmerpkg.com/latest-tar-version
#         specified_version=`curl -sS $latest_url`
#         version_type='latest'
#       elif [ "$1" = '--version' ]; then
#         specified_version=$2
#         version_type='specified'
#       elif [ "$1" = '--rc' ]; then
#         latest_url=https://wasmerpkg.com/latest-rc-version
#         specified_version=`curl -sS $latest_url`
#         version_type='rc'
#       else
#         latest_url=https://wasmerpkg.com/latest-version
#         specified_version=`curl -sS $latest_url`
#         version_type='latest'
#       fi
#       wasmer_version=`wasmer -V`
#       wasmer_alt_version=`wasmer --version`

#       if [ "$specified_version" = "$wasmer_version" -o "$specified_version" = "$wasmer_alt_version" ]; then
#         printf "$green> Wasmer is already at the $specified_version version.$reset\n"
#         exit 0
#       else
#       	printf "$yellow> $wasmer_alt_version is already installed, Specified version: $specified_version.$reset\n"
#         rm -rf "$HOME/.wasmer"
#       fi
#     else
#       printf "$red> $HOME/.wasmer already exists, possibly from a past Wasmer install.$reset\n"
#       printf "$red> Remove it (rm -rf $HOME/.wasmer) and run this script again.$reset\n"
#       exit 0
#     fi
#   fi

  wasmer_download # $1 $2
  wasmer_link
  wasmer_reset
}


wasmer_reset() {
  unset -f wasmer_install wasmer_reset wasmer_download_json wasmer_link wasmer_detect_profile wasmer_download_file wasmer_download wasmer_verify_or_quit
}


wasmer_download() {
  # identify platform based on uname output
  initArch
  initOS

  # determine install directory if required
  if [ -z "$INSTALL_DIRECTORY" ]; then
      # findWasmerBinDirectory INSTALL_DIRECTORY
      INSTALL_DIRECTORY="$HOME/.wasmer"
  fi
  WASMER=INSTALL_DIRECTORY
  printf "$cyan> Getting wasmer releases...$reset\n"

  # assemble expected release artifact name
  BINARY="wasmer-${OS}-${ARCH}"

  # add .exe if on windows
  if [ "$OS" = "windows" ]; then
      BINARY="$BINARY.exe"
  fi

  # if WASMER_RELEASE_TAG was not provided, assume latest
  if [ -z "$WASMER_RELEASE_TAG" ]; then
      wasmer_download_json LATEST_RELEASE "$RELEASES_URL/latest"
      WASMER_RELEASE_TAG=$(echo "${LATEST_RELEASE}" | tr -s '\n' ' ' | sed 's/.*"tag_name":"//' | sed 's/".*//' )
  fi
  printf "$cyan> Latest wasmer release: $WASMER_RELEASE_TAG$reset\n"

  # fetch the real release data to make sure it exists before we attempt a download
  wasmer_download_json RELEASE_DATA "$RELEASES_URL/tag/$WASMER_RELEASE_TAG"

  BINARY_URL="$RELEASES_URL/download/$WASMER_RELEASE_TAG/$BINARY"
  DOWNLOAD_FILE=$(mktemp -t wasmer.XXXXXXXXXX)

  printf "$cyan> Downloading executable...$reset\n"
  wasmer_download_file "$BINARY_URL" "$DOWNLOAD_FILE"

  # echo "Setting executable permissions."
  chmod +x "$DOWNLOAD_FILE"

  INSTALL_NAME="wasmer"

  # windows not supported yet
  # if [ "$OS" = "windows" ]; then
  #     INSTALL_NAME="$INSTALL_NAME.exe"
  # fi

  # echo "Moving executable to $INSTALL_DIRECTORY/$INSTALL_NAME"

  mkdir -p $INSTALL_DIRECTORY/bin
  mv "$DOWNLOAD_FILE" "$INSTALL_DIRECTORY/bin/$INSTALL_NAME"
}

wasmer_verify_or_quit() {
  read -p "$1 [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    printf "$red> Aborting$reset\n"
    exit 1
  fi
}

# cd ~
wasmer_install # $1 $2
