# COPY rootfs - Create all necessary files
mkdir -p /opt/lp/scripts/java
tee /opt/lp/scripts/java/postunpack.sh > /dev/null <<EOT
#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /opt/lp/scripts/libfile.sh
. /opt/lp/scripts/liblog.sh

#
# Java post-unpack operations
#

# Override default files in the Java security directory. This is used for
# custom base images (with custom CA certificates or block lists is used)

if [[ -n "\${JAVA_EXTRA_SECURITY_DIR:-}" ]] && ! is_dir_empty "\$JAVA_EXTRA_SECURITY_DIR"; then
    info "Adding custom CAs to the Java security folder"
    cp -Lr "\${JAVA_EXTRA_SECURITY_DIR}/." /opt/lp/java/lib/security
fi
EOT

echo 
ls -al /opt/lp/scripts/java/postunpack.sh

mkdir -p /opt/lp/scripts/locales
tee /opt/lp/scripts/locales/add-extra-locales.sh > /dev/null <<EOT
#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Defaults
WITH_ALL_LOCALES="\${WITH_ALL_LOCALES:-no}"
EXTRA_LOCALES="\${EXTRA_LOCALES:-}"

# Constants
LOCALES_FILE="/etc/locale.gen"
SUPPORTED_LOCALES_FILE="/usr/share/i18n/SUPPORTED"

# Helper function for enabling locale only when it was not added before
enable_locale() {
    local -r locale="\${1:?missing locale}"
    if ! grep -q -E "^\${locale}\$" "\$SUPPORTED_LOCALES_FILE"; then
        echo "Locale \${locale} is not supported in this system"
        return 1
    fi
    if ! grep -q -E "^\${locale}" "\$LOCALES_FILE"; then
        echo "\$locale" >> "\$LOCALES_FILE"
    else
        echo "Locale \${locale} is already enabled"
    fi
}

if [[ "\$WITH_ALL_LOCALES" =~ ^(yes|true|1)\$ ]]; then
    echo "Enabling all locales"
    cp "\$SUPPORTED_LOCALES_FILE" "\$LOCALES_FILE"
else
    # shellcheck disable=SC2001
    LOCALES_TO_ADD="\$(sed 's/[,;]\s*/\n/g' <<< "\$EXTRA_LOCALES")"
    while [[ -n "\$LOCALES_TO_ADD" ]] && read -r locale; do
        echo "Enabling locale \${locale}"
        enable_locale "\$locale"
    done <<< "\$LOCALES_TO_ADD"
fi

locale-gen
EOT

echo 
ls -al /opt/lp/scripts/locales/add-extra-locales.sh

# --------------------------------



# COPY prebuildfs - Create all necessary files
mkdir -p /opt/lp
tee /opt/lp/.lp_components.json > /dev/null <<EOT
{
    "java": {
        "arch": "amd64",
        "distro": "debian-11",
        "type": "NAMI",
        "version": "1.8.372-7-1"
    }
}
EOT

echo 
ls -al /opt/lp/.lp_components.json

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/liblp.sh > /dev/null <<EOT
#!/bin/bash
#
# LinuxPolska custom library

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh

# Constants
BOLD='[1m'

# Functions

########################
# Print the welcome page
# Globals:
#   DISABLE_WELCOME_MESSAGE
#   LP_APP_NAME
# Arguments:
#   None
# Returns:
#   None
#########################
print_welcome_page() {
    if [[ -z "\${DISABLE_WELCOME_MESSAGE:-}" ]]; then
        if [[ -n "\$LP_APP_NAME" ]]; then
            print_image_welcome_page
        fi
    fi
}

########################
# Print the welcome page for a LinuxPolska Docker image
# Globals:
#   LP_APP_NAME
# Arguments:
#   None
# Returns:
#   None
#########################
print_image_welcome_page() {
    local github_url="https://github.com/lp/containers"

    log ""
    log "\${BOLD}Welcome to the LinuxPolska \${LP_APP_NAME} container\${RESET}"
    log "Subscribe to project updates by watching \${BOLD}\${github_url}\${RESET}"
    log "Submit issues and feature requests at \${BOLD}\${github_url}/issues\${RESET}"
    log ""
}
EOT

echo 
ls -al /opt/lp/scripts/liblp.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libfile.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for managing files

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/libos.sh

# Functions

########################
# Replace a regex-matching string in a file
# Arguments:
#   \$1 - filename
#   \$2 - match regex
#   \$3 - substitute regex
#   \$4 - use POSIX regex. Default: true
# Returns:
#   None
#########################
replace_in_file() {
    local filename="\${1:?filename is required}"
    local match_regex="\${2:?match regex is required}"
    local substitute_regex="\${3:?substitute regex is required}"
    local posix_regex=\${4:-true}

    local result

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    local -r del=\$'' # Use a non-printable character as a 'sed' delimiter to avoid issues
    if [[ \$posix_regex = true ]]; then
        result="\$(sed -E "s\${del}\${match_regex}\${del}\${substitute_regex}\${del}g" "\$filename")"
    else
        result="\$(sed "s\${del}\${match_regex}\${del}\${substitute_regex}\${del}g" "\$filename")"
    fi
    echo "\$result" > "\$filename"
}

########################
# Replace a regex-matching multiline string in a file
# Arguments:
#   \$1 - filename
#   \$2 - match regex
#   \$3 - substitute regex
# Returns:
#   None
#########################
replace_in_file_multiline() {
    local filename="\${1:?filename is required}"
    local match_regex="\${2:?match regex is required}"
    local substitute_regex="\${3:?substitute regex is required}"

    local result
    local -r del=\$'' # Use a non-printable character as a 'sed' delimiter to avoid issues
    result="\$(perl -pe "BEGIN{undef \$/;} s\${del}\${match_regex}\${del}\${substitute_regex}\${del}sg" "\$filename")"
    echo "\$result" > "\$filename"
}

########################
# Remove a line in a file based on a regex
# Arguments:
#   \$1 - filename
#   \$2 - match regex
#   \$3 - use POSIX regex. Default: true
# Returns:
#   None
#########################
remove_in_file() {
    local filename="\${1:?filename is required}"
    local match_regex="\${2:?match regex is required}"
    local posix_regex=\${3:-true}
    local result

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    if [[ \$posix_regex = true ]]; then
        result="\$(sed -E "/\$match_regex/d" "\$filename")"
    else
        result="\$(sed "/\$match_regex/d" "\$filename")"
    fi
    echo "\$result" > "\$filename"
}

########################
# Appends text after the last line matching a pattern
# Arguments:
#   \$1 - file
#   \$2 - match regex
#   \$3 - contents to add
# Returns:
#   None
#########################
append_file_after_last_match() {
    local file="\${1:?missing file}"
    local match_regex="\${2:?missing pattern}"
    local value="\${3:?missing value}"

    # We read the file in reverse, replace the first match (0,/pattern/s) and then reverse the results again
    result="\$(tac "\$file" | sed -E "0,/(\$match_regex)/s||\${value}\n\1|" | tac)"
    echo "\$result" > "\$file"
}

########################
# Wait until certain entry is present in a log file
# Arguments:
#   \$1 - entry to look for
#   \$2 - log file
#   \$3 - max retries. Default: 12
#   \$4 - sleep between retries (in seconds). Default: 5
# Returns:
#   Boolean
#########################
wait_for_log_entry() {
    local -r entry="\${1:-missing entry}"
    local -r log_file="\${2:-missing log file}"
    local -r retries="\${3:-12}"
    local -r interval_time="\${4:-5}"
    local attempt=0

    check_log_file_for_entry() {
        if ! grep -qE "\$entry" "\$log_file"; then
            debug "Entry \"\${entry}\" still not present in \${log_file} (attempt \$((++attempt))/\${retries})"
            return 1
        fi
    }
    debug "Checking that \${log_file} log file contains entry \"\${entry}\""
    if retry_while check_log_file_for_entry "\$retries" "\$interval_time"; then
        debug "Found entry \"\${entry}\" in \${log_file}"
        true
    else
        error "Could not find entry \"\${entry}\" in \${log_file} after \${retries} retries"
        debug_execute cat "\$log_file"
        return 1
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libfile.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libfs.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for file system actions

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh

# Functions

########################
# Ensure a file/directory is owned (user and group) but the given user
# Arguments:
#   \$1 - filepath
#   \$2 - owner
# Returns:
#   None
#########################
owned_by() {
    local path="\${1:?path is missing}"
    local owner="\${2:?owner is missing}"
    local group="\${3:-}"

    if [[ -n \$group ]]; then
        chown "\$owner":"\$group" "\$path"
    else
        chown "\$owner":"\$owner" "\$path"
    fi
}

########################
# Ensure a directory exists and, optionally, is owned by the given user
# Arguments:
#   \$1 - directory
#   \$2 - owner
# Returns:
#   None
#########################
ensure_dir_exists() {
    local dir="\${1:?directory is missing}"
    local owner_user="\${2:-}"
    local owner_group="\${3:-}"

    [ -d "\${dir}" ] || mkdir -p "\${dir}"
    if [[ -n \$owner_user ]]; then
        owned_by "\$dir" "\$owner_user" "\$owner_group"
    fi
}

########################
# Checks whether a directory is empty or not
# arguments:
#   \$1 - directory
# returns:
#   boolean
#########################
is_dir_empty() {
    local -r path="\${1:?missing directory}"
    # Calculate real path in order to avoid issues with symlinks
    local -r dir="\$(realpath "\$path")"
    if [[ ! -e "\$dir" ]] || [[ -z "\$(ls -A "\$dir")" ]]; then
        true
    else
        false
    fi
}

########################
# Checks whether a mounted directory is empty or not
# arguments:
#   \$1 - directory
# returns:
#   boolean
#########################
is_mounted_dir_empty() {
    local dir="\${1:?missing directory}"

    if is_dir_empty "\$dir" || find "\$dir" -mindepth 1 -maxdepth 1 -not -name ".snapshot" -not -name "lost+found" -exec false {} +; then
        true
    else
        false
    fi
}

########################
# Checks whether a file can be written to or not
# arguments:
#   \$1 - file
# returns:
#   boolean
#########################
is_file_writable() {
    local file="\${1:?missing file}"
    local dir
    dir="\$(dirname "\$file")"

    if [[ (-f "\$file" && -w "\$file") || (! -f "\$file" && -d "\$dir" && -w "\$dir") ]]; then
        true
    else
        false
    fi
}

########################
# Relativize a path
# arguments:
#   \$1 - path
#   \$2 - base
# returns:
#   None
#########################
relativize() {
    local -r path="\${1:?missing path}"
    local -r base="\${2:?missing base}"
    pushd "\$base" >/dev/null || exit
    realpath -q --no-symlinks --relative-base="\$base" "\$path" | sed -e 's|^/\$|.|' -e 's|^/||'
    popd >/dev/null || exit
}

########################
# Configure permisions and ownership recursively
# Globals:
#   None
# Arguments:
#   \$1 - paths (as a string).
# Flags:
#   -f|--file-mode - mode for directories.
#   -d|--dir-mode - mode for files.
#   -u|--user - user
#   -g|--group - group
# Returns:
#   None
#########################
configure_permissions_ownership() {
    local -r paths="\${1:?paths is missing}"
    local dir_mode=""
    local file_mode=""
    local user=""
    local group=""

    # Validate arguments
    shift 1
    while [ "\$#" -gt 0 ]; do
        case "\$1" in
        -f | --file-mode)
            shift
            file_mode="\${1:?missing mode for files}"
            ;;
        -d | --dir-mode)
            shift
            dir_mode="\${1:?missing mode for directories}"
            ;;
        -u | --user)
            shift
            user="\${1:?missing user}"
            ;;
        -g | --group)
            shift
            group="\${1:?missing group}"
            ;;
        *)
            echo "Invalid command line flag \$1" >&2
            return 1
            ;;
        esac
        shift
    done

    read -r -a filepaths <<<"\$paths"
    for p in "\${filepaths[@]}"; do
        if [[ -e "\$p" ]]; then
            find -L "\$p" -printf ""
            if [[ -n \$dir_mode ]]; then
                find -L "\$p" -type d ! -perm "\$dir_mode" -print0 | xargs -r -0 chmod "\$dir_mode"
            fi
            if [[ -n \$file_mode ]]; then
                find -L "\$p" -type f ! -perm "\$file_mode" -print0 | xargs -r -0 chmod "\$file_mode"
            fi
            if [[ -n \$user ]] && [[ -n \$group ]]; then
                find -L "\$p" -print0 | xargs -r -0 chown "\${user}:\${group}"
            elif [[ -n \$user ]] && [[ -z \$group ]]; then
                find -L "\$p" -print0 | xargs -r -0 chown "\${user}"
            elif [[ -z \$user ]] && [[ -n \$group ]]; then
                find -L "\$p" -print0 | xargs -r -0 chgrp "\${group}"
            fi
        else
            stderr_print "\$p does not exist"
        fi
    done
}
EOT

echo 
ls -al /opt/lp/scripts/libfs.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libhook.sh > /dev/null <<EOT
#!/bin/bash
#
# Library to use for scripts expected to be used as Kubernetes lifecycle hooks

# shellcheck disable=SC1091

# Load generic libraries
. /opt/lp/scripts/liblog.sh
. /opt/lp/scripts/libos.sh

# Override functions that log to stdout/stderr of the current process, so they print to process 1
for function_to_override in stderr_print debug_execute; do
    # Output is sent to output of process 1 and thus end up in the container log
    # The hook output in general isn't saved
    eval "\$(declare -f "\$function_to_override") >/proc/1/fd/1 2>/proc/1/fd/2"
done
EOT

echo 
ls -al /opt/lp/scripts/libhook.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/liblog.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for logging functions

# Constants
RESET='[0m'
RED='[38;5;1m'
GREEN='[38;5;2m'
YELLOW='[38;5;3m'
MAGENTA='[38;5;5m'
CYAN='[38;5;6m'

# Functions

########################
# Print to STDERR
# Arguments:
#   Message to print
# Returns:
#   None
#########################
stderr_print() {
    # 'is_boolean_yes' is defined in libvalidations.sh, but depends on this file so we cannot source it
    local bool="\${LP_QUIET:-false}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if ! [[ "\$bool" = 1 || "\$bool" =~ ^(yes|true)\$ ]]; then
        printf "%b\
" "\${*}" >&2
    fi
}

########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
log() {
    stderr_print "\${CYAN}\${MODULE:-} \${MAGENTA}\$(date "+%T.%2N ")\${RESET}\${*}"
}
########################
# Log an 'info' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
info() {
    log "\${GREEN}INFO \${RESET} ==> \${*}"
}
########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
warn() {
    log "\${YELLOW}WARN \${RESET} ==> \${*}"
}
########################
# Log an 'error' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
error() {
    log "\${RED}ERROR\${RESET} ==> \${*}"
}
########################
# Log a 'debug' message
# Globals:
#   LP_DEBUG
# Arguments:
#   None
# Returns:
#   None
#########################
debug() {
    # 'is_boolean_yes' is defined in libvalidations.sh, but depends on this file so we cannot source it
    local bool="\${LP_DEBUG:-false}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if [[ "\$bool" = 1 || "\$bool" =~ ^(yes|true)\$ ]]; then
        log "\${MAGENTA}DEBUG\${RESET} ==> \${*}"
    fi
}

########################
# Indent a string
# Arguments:
#   \$1 - string
#   \$2 - number of indentation characters (default: 4)
#   \$3 - indentation character (default: " ")
# Returns:
#   None
#########################
indent() {
    local string="\${1:-}"
    local num="\${2:?missing num}"
    local char="\${3:-" "}"
    # Build the indentation unit string
    local indent_unit=""
    for ((i = 0; i < num; i++)); do
        indent_unit="\${indent_unit}\${char}"
    done
    # shellcheck disable=SC2001
    # Complex regex, see https://github.com/koalaman/shellcheck/wiki/SC2001#exceptions
    echo "\$string" | sed "s/^/\${indent_unit}/"
}
EOT

echo 
ls -al /opt/lp/scripts/liblog.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libnet.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for network functions

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh

# Functions

########################
# Resolve IP address for a host/domain (i.e. DNS lookup)
# Arguments:
#   \$1 - Hostname to resolve
#   \$2 - IP address version (v4, v6), leave empty for resolving to any version
# Returns:
#   IP
#########################
dns_lookup() {
    local host="\${1:?host is missing}"
    local ip_version="\${2:-}"
    getent "ahosts\${ip_version}" "\$host" | awk '/STREAM/ {print \$1 }' | head -n 1
}

#########################
# Wait for a hostname and return the IP
# Arguments:
#   \$1 - hostname
#   \$2 - number of retries
#   \$3 - seconds to wait between retries
# Returns:
#   - IP address that corresponds to the hostname
#########################
wait_for_dns_lookup() {
    local hostname="\${1:?hostname is missing}"
    local retries="\${2:-5}"
    local seconds="\${3:-1}"
    check_host() {
        if [[ \$(dns_lookup "\$hostname") == "" ]]; then
            false
        else
            true
        fi
    }
    # Wait for the host to be ready
    retry_while "check_host \${hostname}" "\$retries" "\$seconds"
    dns_lookup "\$hostname"
}

########################
# Get machine's IP
# Arguments:
#   None
# Returns:
#   Machine IP
#########################
get_machine_ip() {
    local -a ip_addresses
    local hostname
    hostname="\$(hostname)"
    read -r -a ip_addresses <<< "\$(dns_lookup "\$hostname" | xargs echo)"
    if [[ "\${#ip_addresses[@]}" -gt 1 ]]; then
        warn "Found more than one IP address associated to hostname \${hostname}: \${ip_addresses[*]}, will use \${ip_addresses[0]}"
    elif [[ "\${#ip_addresses[@]}" -lt 1 ]]; then
        error "Could not find any IP address associated to hostname \${hostname}"
        exit 1
    fi
    echo "\${ip_addresses[0]}"
}

########################
# Check if the provided argument is a resolved hostname
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_hostname_resolved() {
    local -r host="\${1:?missing value}"
    if [[ -n "\$(dns_lookup "\$host")" ]]; then
        true
    else
        false
    fi
}

########################
# Parse URL
# Globals:
#   None
# Arguments:
#   \$1 - uri - String
#   \$2 - component to obtain. Valid options (scheme, authority, userinfo, host, port, path, query or fragment) - String
# Returns:
#   String
parse_uri() {
    local uri="\${1:?uri is missing}"
    local component="\${2:?component is missing}"

    # Solution based on https://tools.ietf.org/html/rfc3986#appendix-B with
    # additional sub-expressions to split authority into userinfo, host and port
    # Credits to Patryk Obara (see https://stackoverflow.com/a/45977232/6694969)
    local -r URI_REGEX='^(([^:/?#]+):)?(//((([^@/?#]+)@)?([^:/?#]+)(:([0-9]+))?))?(/([^?#]*))?(\?([^#]*))?(#(.*))?'
    #                    ||            |  |||            |         | |            | |         |  |        | |
    #                    |2 scheme     |  ||6 userinfo   7 host    | 9 port       | 11 rpath  |  13 query | 15 fragment
    #                    1 scheme:     |  |5 userinfo@             8 :...         10 path     12 ?...     14 #...
    #                                  |  4 authority
    #                                  3 //...
    local index=0
    case "\$component" in
        scheme)
            index=2
            ;;
        authority)
            index=4
            ;;
        userinfo)
            index=6
            ;;
        host)
            index=7
            ;;
        port)
            index=9
            ;;
        path)
            index=10
            ;;
        query)
            index=13
            ;;
        fragment)
            index=14
            ;;
        *)
            stderr_print "unrecognized component \$component"
            return 1
            ;;
    esac
    [[ "\$uri" =~ \$URI_REGEX ]] && echo "\${BASH_REMATCH[\${index}]}"
}

########################
# Wait for a HTTP connection to succeed
# Globals:
#   *
# Arguments:
#   \$1 - URL to wait for
#   \$2 - Maximum amount of retries (optional)
#   \$3 - Time between retries (optional)
# Returns:
#   true if the HTTP connection succeeded, false otherwise
#########################
wait_for_http_connection() {
    local url="\${1:?missing url}"
    local retries="\${2:-}"
    local sleep_time="\${3:-}"
    if ! retry_while "debug_execute curl --silent \${url}" "\$retries" "\$sleep_time"; then
        error "Could not connect to \${url}"
        return 1
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libnet.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libos.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for operating system actions

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh
. /opt/lp/scripts/libfs.sh
. /opt/lp/scripts/libvalidations.sh

# Functions

########################
# Check if an user exists in the system
# Arguments:
#   \$1 - user
# Returns:
#   Boolean
#########################
user_exists() {
    local user="\${1:?user is missing}"
    id "\$user" >/dev/null 2>&1
}

########################
# Check if a group exists in the system
# Arguments:
#   \$1 - group
# Returns:
#   Boolean
#########################
group_exists() {
    local group="\${1:?group is missing}"
    getent group "\$group" >/dev/null 2>&1
}

########################
# Create a group in the system if it does not exist already
# Arguments:
#   \$1 - group
# Flags:
#   -i|--gid - the ID for the new group
#   -s|--system - Whether to create new user as system user (uid <= 999)
# Returns:
#   None
#########################
ensure_group_exists() {
    local group="\${1:?group is missing}"
    local gid=""
    local is_system_user=false

    # Validate arguments
    shift 1
    while [ "\$#" -gt 0 ]; do
        case "\$1" in
        -i | --gid)
            shift
            gid="\${1:?missing gid}"
            ;;
        -s | --system)
            is_system_user=true
            ;;
        *)
            echo "Invalid command line flag \$1" >&2
            return 1
            ;;
        esac
        shift
    done

    if ! group_exists "\$group"; then
        local -a args=("\$group")
        if [[ -n "\$gid" ]]; then
            if group_exists "\$gid"; then
                error "The GID \$gid is already in use." >&2
                return 1
            fi
            args+=("--gid" "\$gid")
        fi
        \$is_system_user && args+=("--system")
        groupadd "\${args[@]}" >/dev/null 2>&1
    fi
}

########################
# Create an user in the system if it does not exist already
# Arguments:
#   \$1 - user
# Flags:
#   -i|--uid - the ID for the new user
#   -g|--group - the group the new user should belong to
#   -a|--append-groups - comma-separated list of supplemental groups to append to the new user
#   -h|--home - the home directory for the new user
#   -s|--system - whether to create new user as system user (uid <= 999)
# Returns:
#   None
#########################
ensure_user_exists() {
    local user="\${1:?user is missing}"
    local uid=""
    local group=""
    local append_groups=""
    local home=""
    local is_system_user=false

    # Validate arguments
    shift 1
    while [ "\$#" -gt 0 ]; do
        case "\$1" in
        -i | --uid)
            shift
            uid="\${1:?missing uid}"
            ;;
        -g | --group)
            shift
            group="\${1:?missing group}"
            ;;
        -a | --append-groups)
            shift
            append_groups="\${1:?missing append_groups}"
            ;;
        -h | --home)
            shift
            home="\${1:?missing home directory}"
            ;;
        -s | --system)
            is_system_user=true
            ;;
        *)
            echo "Invalid command line flag \$1" >&2
            return 1
            ;;
        esac
        shift
    done

    if ! user_exists "\$user"; then
        local -a user_args=("-N" "\$user")
        if [[ -n "\$uid" ]]; then
            if user_exists "\$uid"; then
                error "The UID \$uid is already in use."
                return 1
            fi
            user_args+=("--uid" "\$uid")
        else
            \$is_system_user && user_args+=("--system")
        fi
        useradd "\${user_args[@]}" >/dev/null 2>&1
    fi

    if [[ -n "\$group" ]]; then
        local -a group_args=("\$group")
        \$is_system_user && group_args+=("--system")
        ensure_group_exists "\${group_args[@]}"
        usermod -g "\$group" "\$user" >/dev/null 2>&1
    fi

    if [[ -n "\$append_groups" ]]; then
        local -a groups
        read -ra groups <<<"\$(tr ',;' ' ' <<<"\$append_groups")"
        for group in "\${groups[@]}"; do
            ensure_group_exists "\$group"
            usermod -aG "\$group" "\$user" >/dev/null 2>&1
        done
    fi

    if [[ -n "\$home" ]]; then
        mkdir -p "\$home"
        usermod -d "\$home" "\$user" >/dev/null 2>&1
        configure_permissions_ownership "\$home" -d "775" -f "664" -u "\$user" -g "\$group"
    fi
}

########################
# Check if the script is currently running as root
# Arguments:
#   \$1 - user
#   \$2 - group
# Returns:
#   Boolean
#########################
am_i_root() {
    if [[ "\$(id -u)" = "0" ]]; then
        true
    else
        false
    fi
}

########################
# Print OS metadata
# Arguments:
#   \$1 - Flag name
# Flags:
#   --id - Distro ID
#   --version - Distro version
#   --branch - Distro branch
#   --codename - Distro codename
#   --name - Distro name
#   --pretty-name - Distro pretty name
# Returns:
#   String
#########################
get_os_metadata() {
    local -r flag_name="\${1:?missing flag}"
    # Helper function
    get_os_release_metadata() {
        local -r env_name="\${1:?missing environment variable name}"
        (
            . /etc/os-release
            echo "\${!env_name}"
        )
    }
    case "\$flag_name" in
    --id)
        get_os_release_metadata ID
        ;;
    --version)
        get_os_release_metadata VERSION_ID
        ;;
    --branch)
        get_os_release_metadata VERSION_ID | sed 's/\..*//'
        ;;
    --codename)
        get_os_release_metadata VERSION_CODENAME
        ;;
    --name)
        get_os_release_metadata NAME
        ;;
    --pretty-name)
        get_os_release_metadata PRETTY_NAME
        ;;
    *)
        error "Unknown flag \${flag_name}"
        return 1
        ;;
    esac
}

########################
# Get total memory available
# Arguments:
#   None
# Returns:
#   Memory in bytes
#########################
get_total_memory() {
    echo \$((\$(grep MemTotal /proc/meminfo | awk '{print \$2}') / 1024))
}

########################
# Get machine size depending on specified memory
# Globals:
#   None
# Arguments:
#   None
# Flags:
#   --memory - memory size (optional)
# Returns:
#   Detected instance size
#########################
get_machine_size() {
    local memory=""
    # Validate arguments
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
        --memory)
            shift
            memory="\${1:?missing memory}"
            ;;
        *)
            echo "Invalid command line flag \$1" >&2
            return 1
            ;;
        esac
        shift
    done
    if [[ -z "\$memory" ]]; then
        debug "Memory was not specified, detecting available memory automatically"
        memory="\$(get_total_memory)"
    fi
    sanitized_memory=\$(convert_to_mb "\$memory")
    if [[ "\$sanitized_memory" -gt 26000 ]]; then
        echo 2xlarge
    elif [[ "\$sanitized_memory" -gt 13000 ]]; then
        echo xlarge
    elif [[ "\$sanitized_memory" -gt 6000 ]]; then
        echo large
    elif [[ "\$sanitized_memory" -gt 3000 ]]; then
        echo medium
    elif [[ "\$sanitized_memory" -gt 1500 ]]; then
        echo small
    else
        echo micro
    fi
}

########################
# Get machine size depending on specified memory
# Globals:
#   None
# Arguments:
#   \$1 - memory size (optional)
# Returns:
#   Detected instance size
#########################
get_supported_machine_sizes() {
    echo micro small medium large xlarge 2xlarge
}

########################
# Convert memory size from string to amount of megabytes (i.e. 2G -> 2048)
# Globals:
#   None
# Arguments:
#   \$1 - memory size
# Returns:
#   Result of the conversion
#########################
convert_to_mb() {
    local amount="\${1:-}"
    if [[ \$amount =~ ^([0-9]+)(m|M|g|G) ]]; then
        size="\${BASH_REMATCH[1]}"
        unit="\${BASH_REMATCH[2]}"
        if [[ "\$unit" = "g" || "\$unit" = "G" ]]; then
            amount="\$((size * 1024))"
        else
            amount="\$size"
        fi
    fi
    echo "\$amount"
}

#########################
# Redirects output to /dev/null if debug mode is disabled
# Globals:
#   LP_DEBUG
# Arguments:
#   \$@ - Command to execute
# Returns:
#   None
#########################
debug_execute() {
    if is_boolean_yes "\${LP_DEBUG:-false}"; then
        "\$@"
    else
        "\$@" >/dev/null 2>&1
    fi
}

########################
# Retries a command a given number of times
# Arguments:
#   \$1 - cmd (as a string)
#   \$2 - max retries. Default: 12
#   \$3 - sleep between retries (in seconds). Default: 5
# Returns:
#   Boolean
#########################
retry_while() {
    local cmd="\${1:?cmd is missing}"
    local retries="\${2:-12}"
    local sleep_time="\${3:-5}"
    local return_value=1

    read -r -a command <<<"\$cmd"
    for ((i = 1; i <= retries; i += 1)); do
        "\${command[@]}" && return_value=0 && break
        sleep "\$sleep_time"
    done
    return \$return_value
}

########################
# Generate a random string
# Arguments:
#   -t|--type - String type (ascii, alphanumeric, numeric), defaults to ascii
#   -c|--count - Number of characters, defaults to 32
# Arguments:
#   None
# Returns:
#   None
# Returns:
#   String
#########################
generate_random_string() {
    local type="ascii"
    local count="32"
    local filter
    local result
    # Validate arguments
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
        -t | --type)
            shift
            type="\$1"
            ;;
        -c | --count)
            shift
            count="\$1"
            ;;
        *)
            echo "Invalid command line flag \$1" >&2
            return 1
            ;;
        esac
        shift
    done
    # Validate type
    case "\$type" in
    ascii)
        filter="[:print:]"
        ;;
    numeric)
        filter="0-9"
        ;;
    alphanumeric)
        filter="a-zA-Z0-9"
        ;;
    alphanumeric+special|special+alphanumeric)
        # Limit variety of special characters, so there is a higher chance of containing more alphanumeric characters
        # Special characters are harder to write, and it could impact the overall UX if most passwords are too complex
        filter='a-zA-Z0-9:@.,/+!='
        ;;
    *)
        echo "Invalid type \${type}" >&2
        return 1
        ;;
    esac
    # Obtain count + 10 lines from /dev/urandom to ensure that the resulting string has the expected size
    # Note there is a very small chance of strings starting with EOL character
    # Therefore, the higher amount of lines read, this will happen less frequently
    result="\$(head -n "\$((count + 10))" /dev/urandom | tr -dc "\$filter" | head -c "\$count")"
    echo "\$result"
}

########################
# Create md5 hash from a string
# Arguments:
#   \$1 - string
# Returns:
#   md5 hash - string
#########################
generate_md5_hash() {
    local -r str="\${1:?missing input string}"
    echo -n "\$str" | md5sum | awk '{print \$1}'
}

########################
# Create sha1 hash from a string
# Arguments:
#   \$1 - string
#   \$2 - algorithm - 1 (default), 224, 256, 384, 512
# Returns:
#   sha1 hash - string
#########################
generate_sha_hash() {
    local -r str="\${1:?missing input string}"
    local -r algorithm="\${2:-1}"
    echo -n "\$str" | "sha\${algorithm}sum" | awk '{print \$1}'
}

########################
# Converts a string to its hexadecimal representation
# Arguments:
#   \$1 - string
# Returns:
#   hexadecimal representation of the string
#########################
convert_to_hex() {
    local -r str=\${1:?missing input string}
    local -i iterator
    local char
    for ((iterator = 0; iterator < \${#str}; iterator++)); do
        char=\${str:iterator:1}
        printf '%x' "'\${char}"
    done
}

########################
# Get boot time
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Boot time metadata
#########################
get_boot_time() {
    stat /proc --format=%Y
}

########################
# Get machine ID
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Machine ID
#########################
get_machine_id() {
    local machine_id
    if [[ -f /etc/machine-id ]]; then
        machine_id="\$(cat /etc/machine-id)"
    fi
    if [[ -z "\$machine_id" ]]; then
        # Fallback to the boot-time, which will at least ensure a unique ID in the current session
        machine_id="\$(get_boot_time)"
    fi
    echo "\$machine_id"
}

########################
# Get the root partition's disk device ID (e.g. /dev/sda1)
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Root partition disk ID
#########################
get_disk_device_id() {
    local device_id=""
    if grep -q ^/dev /proc/mounts; then
        device_id="\$(grep ^/dev /proc/mounts | awk '\$2 == "/" { print \$1 }' | tail -1)"
    fi
    # If it could not be autodetected, fallback to /dev/sda1 as a default
    if [[ -z "\$device_id" || ! -b "\$device_id" ]]; then
        device_id="/dev/sda1"
    fi
    echo "\$device_id"
}

########################
# Get the root disk device ID (e.g. /dev/sda)
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Root disk ID
#########################
get_root_disk_device_id() {
    get_disk_device_id | sed -E 's/p?[0-9]+\$//'
}

########################
# Get the root disk size in bytes
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Root disk size in bytes
#########################
get_root_disk_size() {
    fdisk -l "\$(get_root_disk_device_id)" | grep 'Disk.*bytes' | sed -E 's/.*, ([0-9]+) bytes,.*/\1/' || true
}

########################
# Run command as a specific user and group (optional)
# Arguments:
#   \$1 - USER(:GROUP) to switch to
#   \$2..\$n - command to execute
# Returns:
#   Exit code of the specified command
#########################
run_as_user() {
    run_chroot "\$@"
}

########################
# Execute command as a specific user and group (optional),
# replacing the current process image
# Arguments:
#   \$1 - USER(:GROUP) to switch to
#   \$2..\$n - command to execute
# Returns:
#   Exit code of the specified command
#########################
exec_as_user() {
    run_chroot --replace-process "\$@"
}

########################
# Run a command using chroot
# Arguments:
#   \$1 - USER(:GROUP) to switch to
#   \$2..\$n - command to execute
# Flags:
#   -r | --replace-process - Replace the current process image (optional)
# Returns:
#   Exit code of the specified command
#########################
run_chroot() {
    local userspec
    local user
    local homedir
    local replace=false
    local -r cwd="\$(pwd)"

    # Parse and validate flags
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            -r | --replace-process)
                replace=true
                ;;
            --)
                shift
                break
                ;;
            -*)
                stderr_print "unrecognized flag \$1"
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    # Parse and validate arguments
    if [[ "\$#" -lt 2 ]]; then
        echo "expected at least 2 arguments"
        return 1
    else
        userspec=\$1
        shift

        # userspec can optionally include the group, so we parse the user
        user=\$(echo "\$userspec" | cut -d':' -f1)
    fi

    if ! am_i_root; then
        error "Could not switch to '\${userspec}': Operation not permitted"
        return 1
    fi

    # Get the HOME directory for the user to switch, as chroot does
    # not properly update this env and some scripts rely on it
    homedir=\$(eval echo "~\${user}")
    if [[ ! -d \$homedir ]]; then
        homedir="\${HOME:-/}"
    fi

    # Obtaining value for "\$@" indirectly in order to properly support shell parameter expansion
    if [[ "\$replace" = true ]]; then
        exec chroot --userspec="\$userspec" / bash -c "cd \${cwd}; export HOME=\${homedir}; exec \"\$@\"" -- "\$@"
    else
        chroot --userspec="\$userspec" / bash -c "cd \${cwd}; export HOME=\${homedir}; exec \"\$@\"" -- "\$@"
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libos.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libpersistence.sh > /dev/null <<EOT
#!/bin/bash
#
# LinuxPolska persistence library
# Used for bringing persistence capabilities to applications that don't have clear separation of data and logic

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/libfs.sh
. /opt/lp/scripts/libos.sh
. /opt/lp/scripts/liblog.sh
. /opt/lp/scripts/libversion.sh

# Functions

########################
# Persist an application directory
# Globals:
#   LP_ROOT_DIR
#   LP_VOLUME_DIR
# Arguments:
#   \$1 - App folder name
#   \$2 - List of app files to persist
# Returns:
#   true if all steps succeeded, false otherwise
#########################
persist_app() {
    local -r app="\${1:?missing app}"
    local -a files_to_restore
    read -r -a files_to_persist <<< "\$(tr ',;:' ' ' <<< "\$2")"
    local -r install_dir="\${LP_ROOT_DIR}/\${app}"
    local -r persist_dir="\${LP_VOLUME_DIR}/\${app}"
    # Persist the individual files
    if [[ "\${#files_to_persist[@]}" -le 0 ]]; then
        warn "No files are configured to be persisted"
        return
    fi
    pushd "\$install_dir" >/dev/null || exit
    local file_to_persist_relative file_to_persist_destination file_to_persist_destination_folder
    local -r tmp_file="/tmp/perms.acl"
    for file_to_persist in "\${files_to_persist[@]}"; do
        if [[ ! -f "\$file_to_persist" && ! -d "\$file_to_persist" ]]; then
            error "Cannot persist '\${file_to_persist}' because it does not exist"
            return 1
        fi
        file_to_persist_relative="\$(relativize "\$file_to_persist" "\$install_dir")"
        file_to_persist_destination="\${persist_dir}/\${file_to_persist_relative}"
        file_to_persist_destination_folder="\$(dirname "\$file_to_persist_destination")"
        # Get original permissions for existing files, which will be applied later
        # Exclude the root directory with 'sed', to avoid issues when copying the entirety of it to a volume
        getfacl -R "\$file_to_persist_relative" | sed -E '/# file: (\..+|[^.])/,\$!d' > "\$tmp_file"
        # Copy directories to the volume
        ensure_dir_exists "\$file_to_persist_destination_folder"
        cp -Lr --preserve=links "\$file_to_persist_relative" "\$file_to_persist_destination_folder"
        # Restore permissions
        pushd "\$persist_dir" >/dev/null || exit
        if am_i_root; then
            setfacl --restore="\$tmp_file"
        else
            # When running as non-root, don't change ownership
            setfacl --restore=<(grep -E -v '^# (owner|group):' "\$tmp_file")
        fi
        popd >/dev/null || exit
    done
    popd >/dev/null || exit
    rm -f "\$tmp_file"
    # Install the persisted files into the installation directory, via symlinks
    restore_persisted_app "\$@"
}

########################
# Restore a persisted application directory
# Globals:
#   LP_ROOT_DIR
#   LP_VOLUME_DIR
#   FORCE_MAJOR_UPGRADE
# Arguments:
#   \$1 - App folder name
#   \$2 - List of app files to restore
# Returns:
#   true if all steps succeeded, false otherwise
#########################
restore_persisted_app() {
    local -r app="\${1:?missing app}"
    local -a files_to_restore
    read -r -a files_to_restore <<< "\$(tr ',;:' ' ' <<< "\$2")"
    local -r install_dir="\${LP_ROOT_DIR}/\${app}"
    local -r persist_dir="\${LP_VOLUME_DIR}/\${app}"
    # Restore the individual persisted files
    if [[ "\${#files_to_restore[@]}" -le 0 ]]; then
        warn "No persisted files are configured to be restored"
        return
    fi
    local file_to_restore_relative file_to_restore_origin file_to_restore_destination
    for file_to_restore in "\${files_to_restore[@]}"; do
        file_to_restore_relative="\$(relativize "\$file_to_restore" "\$install_dir")"
        # We use 'realpath --no-symlinks' to ensure that the case of '.' is covered and the directory is removed
        file_to_restore_origin="\$(realpath --no-symlinks "\${install_dir}/\${file_to_restore_relative}")"
        file_to_restore_destination="\$(realpath --no-symlinks "\${persist_dir}/\${file_to_restore_relative}")"
        rm -rf "\$file_to_restore_origin"
        ln -sfn "\$file_to_restore_destination" "\$file_to_restore_origin"
    done
}

########################
# Check if an application directory was already persisted
# Globals:
#   LP_VOLUME_DIR
# Arguments:
#   \$1 - App folder name
# Returns:
#   true if all steps succeeded, false otherwise
#########################
is_app_initialized() {
    local -r app="\${1:?missing app}"
    local -r persist_dir="\${LP_VOLUME_DIR}/\${app}"
    if ! is_mounted_dir_empty "\$persist_dir"; then
        true
    else
        false
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libpersistence.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libservice.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for managing services

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/libvalidations.sh
. /opt/lp/scripts/liblog.sh

# Functions

########################
# Read the provided pid file and returns a PID
# Arguments:
#   \$1 - Pid file
# Returns:
#   PID
#########################
get_pid_from_file() {
    local pid_file="\${1:?pid file is missing}"

    if [[ -f "\$pid_file" ]]; then
        if [[ -n "\$(< "\$pid_file")" ]] && [[ "\$(< "\$pid_file")" -gt 0 ]]; then
            echo "\$(< "\$pid_file")"
        fi
    fi
}

########################
# Check if a provided PID corresponds to a running service
# Arguments:
#   \$1 - PID
# Returns:
#   Boolean
#########################
is_service_running() {
    local pid="\${1:?pid is missing}"

    kill -0 "\$pid" 2>/dev/null
}

########################
# Stop a service by sending a termination signal to its pid
# Arguments:
#   \$1 - Pid file
#   \$2 - Signal number (optional)
# Returns:
#   None
#########################
stop_service_using_pid() {
    local pid_file="\${1:?pid file is missing}"
    local signal="\${2:-}"
    local pid

    pid="\$(get_pid_from_file "\$pid_file")"
    [[ -z "\$pid" ]] || ! is_service_running "\$pid" && return

    if [[ -n "\$signal" ]]; then
        kill "-\${signal}" "\$pid"
    else
        kill "\$pid"
    fi

    local counter=10
    while [[ "\$counter" -ne 0 ]] && is_service_running "\$pid"; do
        sleep 1
        counter=\$((counter - 1))
    done
}

########################
# Start cron daemon
# Arguments:
#   None
# Returns:
#   true if started correctly, false otherwise
#########################
cron_start() {
    if [[ -x "/usr/sbin/cron" ]]; then
        /usr/sbin/cron
    elif [[ -x "/usr/sbin/crond" ]]; then
        /usr/sbin/crond
    else
        false
    fi
}

########################
# Generate a cron configuration file for a given service
# Arguments:
#   \$1 - Service name
#   \$2 - Command
# Flags:
#   --run-as - User to run as (default: root)
#   --schedule - Cron schedule configuration (default: * * * * *)
# Returns:
#   None
#########################
generate_cron_conf() {
    local service_name="\${1:?service name is missing}"
    local cmd="\${2:?command is missing}"
    local run_as="root"
    local schedule="* * * * *"
    local clean="true"

    local clean="true"

    # Parse optional CLI flags
    shift 2
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            --run-as)
                shift
                run_as="\$1"
                ;;
            --schedule)
                shift
                schedule="\$1"
                ;;
            --no-clean)
                clean="false"
                ;;
            *)
                echo "Invalid command line flag \${1}" >&2
                return 1
                ;;
        esac
        shift
    done

    mkdir -p /etc/cron.d
    if "\$clean"; then
        echo "\${schedule} \${run_as} \${cmd}" > /etc/cron.d/"\$service_name"
    else
        echo "\${schedule} \${run_as} \${cmd}" >> /etc/cron.d/"\$service_name"
    fi
}

########################
# Remove a cron configuration file for a given service
# Arguments:
#   \$1 - Service name
# Returns:
#   None
#########################
remove_cron_conf() {
    local service_name="\${1:?service name is missing}"
    local cron_conf_dir="/etc/monit/conf.d"
    rm -f "\${cron_conf_dir}/\${service_name}"
}

########################
# Generate a monit configuration file for a given service
# Arguments:
#   \$1 - Service name
#   \$2 - Pid file
#   \$3 - Start command
#   \$4 - Stop command
# Flags:
#   --disable - Whether to disable the monit configuration
# Returns:
#   None
#########################
generate_monit_conf() {
    local service_name="\${1:?service name is missing}"
    local pid_file="\${2:?pid file is missing}"
    local start_command="\${3:?start command is missing}"
    local stop_command="\${4:?stop command is missing}"
    local monit_conf_dir="/etc/monit/conf.d"
    local disabled="no"

    # Parse optional CLI flags
    shift 4
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            --disable)
                disabled="yes"
                ;;
            *)
                echo "Invalid command line flag \${1}" >&2
                return 1
                ;;
        esac
        shift
    done

    is_boolean_yes "\$disabled" && conf_suffix=".disabled"
    mkdir -p "\$monit_conf_dir"
    cat >"\${monit_conf_dir}/\${service_name}.conf\${conf_suffix:-}" <<EOF
check process \${service_name}
  with pidfile "\${pid_file}"
  start program = "\${start_command}" with timeout 90 seconds
  stop program = "\${stop_command}" with timeout 90 seconds
EOF
}

########################
# Remove a monit configuration file for a given service
# Arguments:
#   \$1 - Service name
# Returns:
#   None
#########################
remove_monit_conf() {
    local service_name="\${1:?service name is missing}"
    local monit_conf_dir="/etc/monit/conf.d"
    rm -f "\${monit_conf_dir}/\${service_name}.conf"
}

########################
# Generate a logrotate configuration file
# Arguments:
#   \$1 - Service name
#   \$2 - Log files pattern
# Flags:
#   --period - Period
#   --rotations - Number of rotations to store
#   --extra - Extra options (Optional)
# Returns:
#   None
#########################
generate_logrotate_conf() {
    local service_name="\${1:?service name is missing}"
    local log_path="\${2:?log path is missing}"
    local period="weekly"
    local rotations="150"
    local extra=""
    local logrotate_conf_dir="/etc/logrotate.d"
    local var_name
    # Parse optional CLI flags
    shift 2
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            --period|--rotations|--extra)
                var_name="\$(echo "\$1" | sed -e "s/^--//" -e "s/-/_/g")"
                shift
                declare "\$var_name"="\${1:?"\$var_name" is missing}"
                ;;
            *)
                echo "Invalid command line flag \${1}" >&2
                return 1
                ;;
        esac
        shift
    done

    mkdir -p "\$logrotate_conf_dir"
    cat <<EOF | sed '/^\s*\$/d' >"\${logrotate_conf_dir}/\${service_name}"
\${log_path} {
  \${period}
  rotate \${rotations}
  dateext
  compress
  copytruncate
  missingok
\$(indent "\$extra" 2)
}
EOF
}

########################
# Remove a logrotate configuration file
# Arguments:
#   \$1 - Service name
# Returns:
#   None
#########################
remove_logrotate_conf() {
    local service_name="\${1:?service name is missing}"
    local logrotate_conf_dir="/etc/logrotate.d"
    rm -f "\${logrotate_conf_dir}/\${service_name}"
}

########################
# Generate a Systemd configuration file
# Arguments:
#   \$1 - Service name
# Flags:
#   --custom-service-content - Custom content to add to the [service] block
#   --environment - Environment variable to define (multiple --environment options may be passed)
#   --environment-file - Text file with environment variables (multiple --environment-file options may be passed)
#   --exec-start - Start command (required)
#   --exec-start-pre - Pre-start command (optional)
#   --exec-start-post - Post-start command (optional)
#   --exec-stop - Stop command (optional)
#   --exec-reload - Reload command (optional)
#   --group - System group to start the service with
#   --name - Service full name (e.g. Apache HTTP Server, defaults to \$1)
#   --restart - When to restart the Systemd service after being stopped (defaults to always)
#   --pid-file - Service PID file
#   --standard-output - File where to print stdout output
#   --standard-error - File where to print stderr output
#   --success-exit-status - Exit code that indicates a successful shutdown
#   --type - Systemd unit type (defaults to forking)
#   --user - System user to start the service with
#   --working-directory - Working directory at which to start the service
# Returns:
#   None
#########################
generate_systemd_conf() {
    local -r service_name="\${1:?service name is missing}"
    local -r systemd_units_dir="/etc/systemd/system"
    local -r service_file="\${systemd_units_dir}/lp.\${service_name}.service"
    # Default values
    local name="\$service_name"
    local type="forking"
    local user=""
    local group=""
    local environment=""
    local environment_file=""
    local exec_start=""
    local exec_start_pre=""
    local exec_start_post=""
    local exec_stop=""
    local exec_reload=""
    local restart="always"
    local pid_file=""
    local standard_output="journal"
    local standard_error=""
    local limits_content=""
    local success_exit_status=""
    local custom_service_content=""
    local working_directory=""
    # Parse CLI flags
    shift
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            --name \
            | --type \
            | --user \
            | --group \
            | --exec-start \
            | --exec-stop \
            | --exec-reload \
            | --restart \
            | --pid-file \
            | --standard-output \
            | --standard-error \
            | --success-exit-status \
            | --custom-service-content \
            | --working-directory \
            )
                var_name="\$(echo "\$1" | sed -e "s/^--//" -e "s/-/_/g")"
                shift
                declare "\$var_name"="\${1:?"\${var_name} value is missing"}"
                ;;
            --limit-*)
                [[ -n "\$limits_content" ]] && limits_content+=\$'\n'
                var_name="\${1//--limit-}"
                shift
                limits_content+="Limit\${var_name^^}=\${1:?"--limit-\${var_name} value is missing"}"
                ;;
            --exec-start-pre)
                shift
                [[ -n "\$exec_start_pre" ]] && exec_start_pre+=\$'\n'
                exec_start_pre+="ExecStartPre=\${1:?"--exec-start-pre value is missing"}"
                ;;
            --exec-start-post)
                shift
                [[ -n "\$exec_start_post" ]] && exec_start_post+=\$'\n'
                exec_start_post+="ExecStartPost=\${1:?"--exec-start-post value is missing"}"
                ;;
            --environment)
                shift
                # It is possible to add multiple environment lines
                [[ -n "\$environment" ]] && environment+=\$'\n'
                environment+="Environment=\${1:?"--environment value is missing"}"
                ;;
            --environment-file)
                shift
                # It is possible to add multiple environment-file lines
                [[ -n "\$environment_file" ]] && environment_file+=\$'\n'
                environment_file+="EnvironmentFile=\${1:?"--environment-file value is missing"}"
                ;;
            *)
                echo "Invalid command line flag \${1}" >&2
                return 1
                ;;
        esac
        shift
    done
    # Validate inputs
    local error="no"
    if [[ -z "\$exec_start" ]]; then
        error "The --exec-start option is required"
        error="yes"
    fi
    if [[ "\$error" != "no" ]]; then
        return 1
    fi
    # Generate the Systemd unit
    cat > "\$service_file" <<EOF
[Unit]
Description=LinuxPolska service for \${name}
# Starting/stopping the main lp service should cause the same effect for this service
PartOf=lp.service

[Service]
Type=\${type}
EOF
    if [[ -n "\$working_directory" ]]; then
        cat >> "\$service_file" <<< "WorkingDirectory=\${working_directory}"
    fi
    if [[ -n "\$exec_start_pre" ]]; then
        # This variable may contain multiple ExecStartPre= directives
        cat >> "\$service_file" <<< "\$exec_start_pre"
    fi
    if [[ -n "\$exec_start" ]]; then
        cat >> "\$service_file" <<< "ExecStart=\${exec_start}"
    fi
    if [[ -n "\$exec_start_post" ]]; then
        # This variable may contain multiple ExecStartPost= directives
        cat >> "\$service_file" <<< "\$exec_start_post"
    fi
    # Optional stop and reload commands
    if [[ -n "\$exec_stop" ]]; then
        cat >> "\$service_file" <<< "ExecStop=\${exec_stop}"
    fi
    if [[ -n "\$exec_reload" ]]; then
        cat >> "\$service_file" <<< "ExecReload=\${exec_reload}"
    fi
    # User and group
    if [[ -n "\$user" ]]; then
        cat >> "\$service_file" <<< "User=\${user}"
    fi
    if [[ -n "\$group" ]]; then
        cat >> "\$service_file" <<< "Group=\${group}"
    fi
    # PID file allows to determine if the main process is running properly (for Restart=always)
    if [[ -n "\$pid_file" ]]; then
        cat >> "\$service_file" <<< "PIDFile=\${pid_file}"
    fi
    if [[ -n "\$restart" ]]; then
        cat >> "\$service_file" <<< "Restart=\${restart}"
    fi
    # Environment flags
    if [[ -n "\$environment" ]]; then
        # This variable may contain multiple Environment= directives
        cat >> "\$service_file" <<< "\$environment"
    fi
    if [[ -n "\$environment_file" ]]; then
        # This variable may contain multiple EnvironmentFile= directives
        cat >> "\$service_file" <<< "\$environment_file"
    fi
    # Logging
    if [[ -n "\$standard_output" ]]; then
        cat >> "\$service_file" <<< "StandardOutput=\${standard_output}"
    fi
    if [[ -n "\$standard_error" ]]; then
        cat >> "\$service_file" <<< "StandardError=\${standard_error}"
    fi
    if [[ -n "\$custom_service_content" ]]; then
        # This variable may contain multiple miscellaneous directives
        cat >> "\$service_file" <<< "\$custom_service_content"
    fi
    if [[ -n "\$success_exit_status" ]]; then
        cat >> "\$service_file" <<EOF
# When the process receives a SIGTERM signal, it exits with code \${success_exit_status}
SuccessExitStatus=\${success_exit_status}
EOF
    fi
    cat >> "\$service_file" <<EOF
# Optimizations
TimeoutStartSec=2min
TimeoutStopSec=30s
IgnoreSIGPIPE=no
KillMode=mixed
EOF
    if [[ -n "\$limits_content" ]]; then
        cat >> "\$service_file" <<EOF
# Limits
\${limits_content}
EOF
    fi
    cat >> "\$service_file" <<EOF

[Install]
# Enabling/disabling the main lp service should cause the same effect for this service
WantedBy=lp.service
EOF
}
EOT

echo 
ls -al /opt/lp/scripts/libservice.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libvalidations.sh > /dev/null <<EOT
#!/bin/bash
#
# Validation functions library

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh

# Functions

########################
# Check if the provided argument is an integer
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_int() {
    local -r int="\${1:?missing value}"
    if [[ "\$int" =~ ^-?[0-9]+ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a positive integer
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_positive_int() {
    local -r int="\${1:?missing value}"
    if is_int "\$int" && (( "\${int}" >= 0 )); then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean or is the string 'yes/true'
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_boolean_yes() {
    local -r bool="\${1:-}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if [[ "\$bool" = 1 || "\$bool" =~ ^(yes|true)\$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean yes/no value
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_yes_no_value() {
    local -r bool="\${1:-}"
    if [[ "\$bool" =~ ^(yes|no)\$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean true/false value
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_true_false_value() {
    local -r bool="\${1:-}"
    if [[ "\$bool" =~ ^(true|false)\$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean 1/0 value
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_1_0_value() {
    local -r bool="\${1:-}"
    if [[ "\$bool" =~ ^[10]\$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is an empty string or not defined
# Arguments:
#   \$1 - Value to check
# Returns:
#   Boolean
#########################
is_empty_value() {
    local -r val="\${1:-}"
    if [[ -z "\$val" ]]; then
        true
    else
        false
    fi
}

########################
# Validate if the provided argument is a valid port
# Arguments:
#   \$1 - Port to validate
# Returns:
#   Boolean and error message
#########################
validate_port() {
    local value
    local unprivileged=0

    # Parse flags
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            -unprivileged)
                unprivileged=1
                ;;
            --)
                shift
                break
                ;;
            -*)
                stderr_print "unrecognized flag \$1"
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [[ "\$#" -gt 1 ]]; then
        echo "too many arguments provided"
        return 2
    elif [[ "\$#" -eq 0 ]]; then
        stderr_print "missing port argument"
        return 1
    else
        value=\$1
    fi

    if [[ -z "\$value" ]]; then
        echo "the value is empty"
        return 1
    else
        if ! is_int "\$value"; then
            echo "value is not an integer"
            return 2
        elif [[ "\$value" -lt 0 ]]; then
            echo "negative value provided"
            return 2
        elif [[ "\$value" -gt 65535 ]]; then
            echo "requested port is greater than 65535"
            return 2
        elif [[ "\$unprivileged" = 1 && "\$value" -lt 1024 ]]; then
            echo "privileged port requested"
            return 3
        fi
    fi
}

########################
# Validate if the provided argument is a valid IPv4 address
# Arguments:
#   \$1 - IP to validate
# Returns:
#   Boolean
#########################
validate_ipv4() {
    local ip="\${1:?ip is missing}"
    local stat=1

    if [[ \$ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$ ]]; then
        read -r -a ip_array <<< "\$(tr '.' ' ' <<< "\$ip")"
        [[ \${ip_array[0]} -le 255 && \${ip_array[1]} -le 255 \
            && \${ip_array[2]} -le 255 && \${ip_array[3]} -le 255 ]]
        stat=\$?
    fi
    return \$stat
}

########################
# Validate a string format
# Arguments:
#   \$1 - String to validate
# Returns:
#   Boolean
#########################
validate_string() {
    local string
    local min_length=-1
    local max_length=-1

    # Parse flags
    while [ "\$#" -gt 0 ]; do
        case "\$1" in
            -min-length)
                shift
                min_length=\${1:-}
                ;;
            -max-length)
                shift
                max_length=\${1:-}
                ;;
            --)
                shift
                break
                ;;
            -*)
                stderr_print "unrecognized flag \$1"
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [ "\$#" -gt 1 ]; then
        stderr_print "too many arguments provided"
        return 2
    elif [ "\$#" -eq 0 ]; then
        stderr_print "missing string"
        return 1
    else
        string=\$1
    fi

    if [[ "\$min_length" -ge 0 ]] && [[ "\${#string}" -lt "\$min_length" ]]; then
        echo "string length is less than \$min_length"
        return 1
    fi
    if [[ "\$max_length" -ge 0 ]] && [[ "\${#string}" -gt "\$max_length" ]]; then
        echo "string length is great than \$max_length"
        return 1
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libvalidations.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libversion.sh > /dev/null <<EOT
#!/bin/bash
#
# Library for managing versions strings

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/lp/scripts/liblog.sh

# Functions
########################
# Gets semantic version
# Arguments:
#   \$1 - version: string to extract major.minor.patch
#   \$2 - section: 1 to extract major, 2 to extract minor, 3 to extract patch
# Returns:
#   array with the major, minor and release
#########################
get_sematic_version () {
    local version="\${1:?version is required}"
    local section="\${2:?section is required}"
    local -a version_sections

    #Regex to parse versions: x.y.z
    local -r regex='([0-9]+)(\.([0-9]+)(\.([0-9]+))?)?'

    if [[ "\$version" =~ \$regex ]]; then
        local i=1
        local j=1
        local n=\${#BASH_REMATCH[*]}

        while [[ \$i -lt \$n ]]; do
            if [[ -n "\${BASH_REMATCH[\$i]}" ]] && [[ "\${BASH_REMATCH[\$i]:0:1}" != '.' ]];  then
                version_sections[j]="\${BASH_REMATCH[\$i]}"
                ((j++))
            fi
            ((i++))
        done

        local number_regex='^[0-9]+\$'
        if [[ "\$section" =~ \$number_regex ]] && (( section > 0 )) && (( section <= 3 )); then
             echo "\${version_sections[\$section]}"
             return
        else
            stderr_print "Section allowed values are: 1, 2, and 3"
            return 1
        fi
    fi
}
EOT

echo 
ls -al /opt/lp/scripts/libversion.sh

mkdir -p /opt/lp/scripts
tee /opt/lp/scripts/libwebserver.sh > /dev/null <<EOT
#!/bin/bash
#
# LinuxPolska web server handler library

# shellcheck disable=SC1090,SC1091

# Load generic libraries
. /opt/lp/scripts/liblog.sh

########################
# Execute a command (or list of commands) with the web server environment and library loaded
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_execute() {
    local -r web_server="\${1:?missing web server}"
    shift
    # Run program in sub-shell to avoid web server environment getting loaded when not necessary
    (
        . "/opt/lp/scripts/lib\${web_server}.sh"
        . "/opt/lp/scripts/\${web_server}-env.sh"
        "\$@"
    )
}

########################
# Prints the list of enabled web servers
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_list() {
    local -r -a supported_web_servers=(apache nginx)
    local -a existing_web_servers=()
    for web_server in "\${supported_web_servers[@]}"; do
        [[ -f "/opt/lp/scripts/\${web_server}-env.sh" ]] && existing_web_servers+=("\$web_server")
    done
    echo "\${existing_web_servers[@]:-}"
}

########################
# Prints the currently-enabled web server type (only one, in order of preference)
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_type() {
    local -a web_servers
    read -r -a web_servers <<< "\$(web_server_list)"
    echo "\${web_servers[0]:-}"
}

########################
# Validate that a supported web server is configured
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_validate() {
    local error_code=0
    local supported_web_servers=("apache" "nginx")

    # Auxiliary functions
    print_validation_error() {
        error "\$1"
        error_code=1
    }

    if [[ -z "\$(web_server_type)" || ! " \${supported_web_servers[*]} " == *" \$(web_server_type) "* ]]; then
        print_validation_error "Could not detect any supported web servers. It must be one of: \${supported_web_servers[*]}"
    elif ! web_server_execute "\$(web_server_type)" type -t "is_\$(web_server_type)_running" >/dev/null; then
        print_validation_error "Could not load the \$(web_server_type) web server library from /opt/lp/scripts. Check that it exists and is readable."
    fi

    return "\$error_code"
}

########################
# Check whether the web server is running
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   true if the web server is running, false otherwise
#########################
is_web_server_running() {
    "is_\$(web_server_type)_running"
}

########################
# Start web server
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_start() {
    info "Starting \$(web_server_type) in background"
    if [[ "\${LP_SERVICE_MANAGER:-}" = "systemd" ]]; then
        systemctl start "lp.\$(web_server_type).service"
    else
        "\${LP_ROOT_DIR}/scripts/\$(web_server_type)/start.sh"
    fi
}

########################
# Stop web server
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_stop() {
    info "Stopping \$(web_server_type)"
    if [[ "\${LP_SERVICE_MANAGER:-}" = "systemd" ]]; then
        systemctl stop "lp.\$(web_server_type).service"
    else
        "\${LP_ROOT_DIR}/scripts/\$(web_server_type)/stop.sh"
    fi
}

########################
# Restart web server
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_restart() {
    info "Restarting \$(web_server_type)"
    if [[ "\${LP_SERVICE_MANAGER:-}" = "systemd" ]]; then
        systemctl restart "lp.\$(web_server_type).service"
    else
        "\${LP_ROOT_DIR}/scripts/\$(web_server_type)/restart.sh"
    fi
}

########################
# Reload web server
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_reload() {
    if [[ "\${LP_SERVICE_MANAGER:-}" = "systemd" ]]; then
        systemctl reload "lp.\$(web_server_type).service"
    else
        "\${LP_ROOT_DIR}/scripts/\$(web_server_type)/reload.sh"
    fi
}

########################
# Ensure a web server application configuration exists (i.e. Apache virtual host format or NGINX server block)
# It serves as a wrapper for the specific web server function
# Globals:
#   *
# Arguments:
#   \$1 - App name
# Flags:
#   --type - Application type, which has an effect on which configuration template to use
#   --hosts - Host listen addresses
#   --server-name - Server name
#   --server-aliases - Server aliases
#   --allow-remote-connections - Whether to allow remote connections or to require local connections
#   --disable - Whether to render server configurations with a .disabled prefix
#   --disable-http - Whether to render the app's HTTP server configuration with a .disabled prefix
#   --disable-https - Whether to render the app's HTTPS server configuration with a .disabled prefix
#   --http-port - HTTP port number
#   --https-port - HTTPS port number
#   --document-root - Path to document root directory
# Apache-specific flags:
#   --apache-additional-configuration - Additional vhost configuration (no default)
#   --apache-additional-http-configuration - Additional HTTP vhost configuration (no default)
#   --apache-additional-https-configuration - Additional HTTPS vhost configuration (no default)
#   --apache-before-vhost-configuration - Configuration to add before the <VirtualHost> directive (no default)
#   --apache-allow-override - Whether to allow .htaccess files (only allowed when --move-htaccess is set to 'no' and type is not defined)
#   --apache-extra-directory-configuration - Extra configuration for the document root directory
#   --apache-proxy-address - Address where to proxy requests
#   --apache-proxy-configuration - Extra configuration for the proxy
#   --apache-proxy-http-configuration - Extra configuration for the proxy HTTP vhost
#   --apache-proxy-https-configuration - Extra configuration for the proxy HTTPS vhost
#   --apache-move-htaccess - Move .htaccess files to a common place so they can be loaded during Apache startup (only allowed when type is not defined)
# NGINX-specific flags:
#   --nginx-additional-configuration - Additional server block configuration (no default)
#   --nginx-external-configuration - Configuration external to server block (no default)
# Returns:
#   true if the configuration was enabled, false otherwise
########################
ensure_web_server_app_configuration_exists() {
    local app="\${1:?missing app}"
    shift
    local -a apache_args nginx_args web_servers args_var
    apache_args=("\$app")
    nginx_args=("\$app")
    # Validate arguments
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            # Common flags
            --disable \
            | --disable-http \
            | --disable-https \
            )
                apache_args+=("\$1")
                nginx_args+=("\$1")
                ;;
            --hosts \
            | --server-name \
            | --server-aliases \
            | --type \
            | --allow-remote-connections \
            | --http-port \
            | --https-port \
            | --document-root \
            )
                apache_args+=("\$1" "\${2:?missing value}")
                nginx_args+=("\$1" "\${2:?missing value}")
                shift
                ;;

            # Specific Apache flags
            --apache-additional-configuration \
            | --apache-additional-http-configuration \
            | --apache-additional-https-configuration \
            | --apache-before-vhost-configuration \
            | --apache-allow-override \
            | --apache-extra-directory-configuration \
            | --apache-proxy-address \
            | --apache-proxy-configuration \
            | --apache-proxy-http-configuration \
            | --apache-proxy-https-configuration \
            | --apache-move-htaccess \
            )
                apache_args+=("\${1//apache-/}" "\${2:?missing value}")
                shift
                ;;

            # Specific NGINX flags
            --nginx-additional-configuration \
            | --nginx-external-configuration)
                nginx_args+=("\${1//nginx-/}" "\${2:?missing value}")
                shift
                ;;

            *)
                echo "Invalid command line flag \$1" >&2
                return 1
                ;;
        esac
        shift
    done
    read -r -a web_servers <<< "\$(web_server_list)"
    for web_server in "\${web_servers[@]}"; do
        args_var="\${web_server}_args[@]"
        web_server_execute "\$web_server" "ensure_\${web_server}_app_configuration_exists" "\${!args_var}"
    done
}

########################
# Ensure a web server application configuration does not exist anymore (i.e. Apache virtual host format or NGINX server block)
# It serves as a wrapper for the specific web server function
# Globals:
#   *
# Arguments:
#   \$1 - App name
# Returns:
#   true if the configuration was disabled, false otherwise
########################
ensure_web_server_app_configuration_not_exists() {
    local app="\${1:?missing app}"
    local -a web_servers
    read -r -a web_servers <<< "\$(web_server_list)"
    for web_server in "\${web_servers[@]}"; do
        web_server_execute "\$web_server" "ensure_\${web_server}_app_configuration_not_exists" "\$app"
    done
}

########################
# Ensure the web server loads the configuration for an application in a URL prefix
# It serves as a wrapper for the specific web server function
# Globals:
#   *
# Arguments:
#   \$1 - App name
# Flags:
#   --allow-remote-connections - Whether to allow remote connections or to require local connections
#   --document-root - Path to document root directory
#   --prefix - URL prefix from where it will be accessible (i.e. /myapp)
#   --type - Application type, which has an effect on what configuration template will be used
# Apache-specific flags:
#   --apache-additional-configuration - Additional vhost configuration (no default)
#   --apache-allow-override - Whether to allow .htaccess files (only allowed when --move-htaccess is set to 'no')
#   --apache-extra-directory-configuration - Extra configuration for the document root directory
#   --apache-move-htaccess - Move .htaccess files to a common place so they can be loaded during Apache startup
# NGINX-specific flags:
#   --nginx-additional-configuration - Additional server block configuration (no default)
# Returns:
#   true if the configuration was enabled, false otherwise
########################
ensure_web_server_prefix_configuration_exists() {
    local app="\${1:?missing app}"
    shift
    local -a apache_args nginx_args web_servers args_var
    apache_args=("\$app")
    nginx_args=("\$app")
    # Validate arguments
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            # Common flags
            --allow-remote-connections \
            | --document-root \
            | --prefix \
            | --type \
            )
                apache_args+=("\$1" "\${2:?missing value}")
                nginx_args+=("\$1" "\${2:?missing value}")
                shift
                ;;

            # Specific Apache flags
            --apache-additional-configuration \
            | --apache-allow-override \
            | --apache-extra-directory-configuration \
            | --apache-move-htaccess \
            )
                apache_args+=("\${1//apache-/}" "\$2")
                shift
                ;;

            # Specific NGINX flags
            --nginx-additional-configuration)
                nginx_args+=("\${1//nginx-/}" "\$2")
                shift
                ;;

            *)
                echo "Invalid command line flag \$1" >&2
                return 1
                ;;
        esac
        shift
    done
    read -r -a web_servers <<< "\$(web_server_list)"
    for web_server in "\${web_servers[@]}"; do
        args_var="\${web_server}_args[@]"
        web_server_execute "\$web_server" "ensure_\${web_server}_prefix_configuration_exists" "\${!args_var}"
    done
}

########################
# Ensure a web server application configuration is updated with the runtime configuration (i.e. ports)
# It serves as a wrapper for the specific web server function
# Globals:
#   *
# Arguments:
#   \$1 - App name
# Flags:
#   --hosts - Host listen addresses
#   --server-name - Server name
#   --server-aliases - Server aliases
#   --enable-http - Enable HTTP app configuration (if not enabled already)
#   --enable-https - Enable HTTPS app configuration (if not enabled already)
#   --disable-http - Disable HTTP app configuration (if not disabled already)
#   --disable-https - Disable HTTPS app configuration (if not disabled already)
#   --http-port - HTTP port number
#   --https-port - HTTPS port number
# Returns:
#   true if the configuration was updated, false otherwise
########################
web_server_update_app_configuration() {
    local app="\${1:?missing app}"
    shift
    local -a args web_servers
    args=("\$app")
    # Validate arguments
    while [[ "\$#" -gt 0 ]]; do
        case "\$1" in
            # Common flags
            --enable-http \
            | --enable-https \
            | --disable-http \
            | --disable-https \
            )
                args+=("\$1")
                ;;
            --hosts \
            | --server-name \
            | --server-aliases \
            | --http-port \
            | --https-port \
            )
                args+=("\$1" "\${2:?missing value}")
                shift
                ;;

            *)
                echo "Invalid command line flag \$1" >&2
                return 1
                ;;
        esac
        shift
    done
    read -r -a web_servers <<< "\$(web_server_list)"
    for web_server in "\${web_servers[@]}"; do
        web_server_execute "\$web_server" "\${web_server}_update_app_configuration" "\${args[@]}"
    done
}

########################
# Enable loading page, which shows users that the initialization process is not yet completed
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_enable_loading_page() {
    ensure_web_server_app_configuration_exists "__loading" --hosts "_default_" \
        --apache-additional-configuration "
# Show a HTTP 503 Service Unavailable page by default
RedirectMatch 503 ^/\$
# Show index.html if server is answering with 404 Not Found or 503 Service Unavailable status codes
ErrorDocument 404 /index.html
ErrorDocument 503 /index.html" \
        --nginx-additional-configuration "
# Show a HTTP 503 Service Unavailable page by default
location / {
  return 503;
}
# Show index.html if server is answering with 404 Not Found or 503 Service Unavailable status codes
error_page 404 @installing;
error_page 503 @installing;
location @installing {
  rewrite ^(.*)\$ /index.html break;
}"
    web_server_reload
}

########################
# Enable loading page, which shows users that the initialization process is not yet completed
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   None
#########################
web_server_disable_install_page() {
    ensure_web_server_app_configuration_not_exists "__loading"
    web_server_reload
}
EOT

echo 
ls -al /opt/lp/scripts/libwebserver.sh

mkdir -p /usr/sbin
tee /usr/sbin/install_packages > /dev/null <<EOT
#!/bin/sh
set -eu

n=0
max=2
export DEBIAN_FRONTEND=noninteractive

until [ \$n -gt \$max ]; do
    set +e
    (
      apt-get update -qq &&
      apt-get install -y --no-install-recommends "\$@"
    )
    CODE=\$?
    set -e
    if [ \$CODE -eq 0 ]; then
        break
    fi
    if [ \$n -eq \$max ]; then
        exit \$CODE
    fi
    echo "apt failed, retrying"
    n=\$((\$n + 1))
done
apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
EOT

echo 
ls -al /usr/sbin/install_packages

# --------------------------------



export HOME="/opt/lp/java/.java" OS_ARCH="${TARGETARCH:-amd64}" OS_FLAVOUR="el9" OS_NAME="eurolinux" PATH="/opt/lp/java/sbin:$PATH"
dnf install -y --setopt=tsflags=nodocs --nobest --allowerasing ca-certificates procps wget java-1.8.0-openjdk-headless
dnf clean all
touch /etc/locale.conf
sed -i 's/^LANG=.*/LANG="en_US.utf8"/' /etc/locale.conf
export LANG=en_US.utf8
sudo bash /opt/lp/scripts/java/postunpack.sh
export APP_VERSION="1.8.372-7" LP_APP_NAME="java" JAVA_HOME="/opt/lp/java" LANG="en_US.UTF-8" LANGUAGE="en_US:en" PATH="/opt/lp/java/bin:$PATH"
. /opt/lp/scripts/liblp.sh
. /opt/lp/scripts/liblog.sh

echo "PATH=\"$PATH\"" >> /etc/bashrc
