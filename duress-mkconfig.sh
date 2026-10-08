#!/bin/sh
set -e

if [ -z "$1" ]; then echo "Usage: $0 action [options...]" >&2 ; exit 1; fi

ACTION="$1"
shift
OPTIONS="$@"

case "$ACTION" in
	boot|wipe) ;;
	*) echo "Action must be one of { boot, wipe }" >&2 ; exit 1 ;;
esac

SALT=$(head -c 16 /dev/urandom | base64)

printf 'Password: ' >&2
IFS= read -rs PASSWORD
echo >&2 # add newline because enter pressed after password is not echoed

HASH=$(printf '%s%s' "$SALT" "$PASSWORD" | sha256sum | cut -d' ' -f1)
unset PASSWORD

printf 'v1,%s,%s,%s,%s\n' "$SALT" "$HASH" "$ACTION" "$OPTIONS"
