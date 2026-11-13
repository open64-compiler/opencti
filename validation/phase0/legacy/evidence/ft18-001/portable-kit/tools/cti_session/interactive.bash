# Sourced by interactive Bash after the working directory is established.
if [ "$CTI_SESSION_BARE" != 1 ]; then
    if ! . "$CTI_SESSION_ENV"; then
        printf 'CTI: saved environment failed to load: %s\n' "$CTI_SESSION_ENV" >&2
        exit 70
    fi
fi
cd -- "$CTI_SESSION_CWD" || exit 70
PS1="cti[${CTI_SESSION_ID:0:8}]:\w\$ "
printf 'CTI debugging session %s\nWorking directory: %s\n' "$CTI_SESSION_ID" "$PWD"
printf 'Exit disconnects this shell; the session and private files remain.\n'
