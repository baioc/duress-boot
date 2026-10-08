#!/usr/bin/ash


run_hook() {
	local password retry line linenumber
	local version salt hash action options

	echo modprobe -a -q dm-crypt > /dev/null 2>&1
	# TODO: plymouth prompts

	retry=1
	while [ "$retry" -eq 1 ]; do
		echo -n 'A password is required to access the encrypted volume: '
		IFS= read -rs password
		echo ''

		linenumber=0
		while read -r line; do
			linenumber=$((linenumber + 1))
			case "$line" in
				'#'*) continue ;;
				''|[[:space:]]*) continue ;;
				*) ;;
			esac
			version=$(echo "$line" | cut -d',' -f1)
			case "$version" in
				v1)
					salt=$(echo "$line" | cut -d',' -f2)
					hash=$(echo "$line" | cut -d',' -f3)
					action=$(echo "$line" | cut -d',' -f4)
					options=$(echo "$line" | cut -d',' -f5-)
					if duress_v1 "$password" "$salt" "$hash" "$action" "$options"; then
						return 0
					fi
					;;
				*)
					msg "Ignoring invalid duress configuration in line $linenumber ..."
					continue
					;;
			esac
		done < ./duress.conf
		# TODO: replace with /etc/duress.conf

		echo -n 'Retry [y/N] ? '
		read -r retry
		case "$retry" in
			y|Y) retry=1 ;;
			*) retry=0 ;;
		esac
	done

	return 0
}


duress_v1() {
	local password="$1" salt="$2" hash="$3" action="$4" options="$5"
	local computed

	computed=$(printf '%s%s' "$salt" "$password" | sha256sum | cut -d' ' -f1)
	if [ "$computed" != "$hash" ]; then
		return 1
	fi

	# except for a successful boot, every action must return 1
	# so that the outer loop will keep going (until either boot or exhaustion)
	case "$action" in
		boot)
			luks_decrypt "$password" "$options"
			return $?
			;;
		wipe)
			luks_wipe "$options"
			return 1
			;;
		*)
			msg "Ignoring unimplemented duress action '$action' ..."
			return 1
			;;
	esac
}


luks_decrypt() {
	local password="$1" options="$2"
	local cryptdev cryptname cryptoptions
	local cryptargs='' resolved

	# defined in /usr/lib/initcpio/init_functions, and called in init, this
	# function exports variables parsed from the kernel cmdline. we do the same
	# here to avoid reimplementing that parsing, and to override with $options
	parse_cmdline <<EOF
$options
EOF

	IFS=: read cryptdev cryptname cryptoptions <<EOF
$cryptdevice
EOF

	OLDIFS="$IFS"
	IFS=','
	for cryptopt in $cryptoptions; do
		case "$cryptopt" in
			allow-discards|discard)
				cryptargs="$cryptargs --allow-discards"
				;;
			no-read-workqueue|perf-no_read_workqueue)
				cryptargs="$cryptargs --perf-no_read_workqueue"
				;;
			no-write-workqueue|perf-no_write_workqueue)
				cryptargs="$cryptargs --perf-no_write_workqueue"
				;;
			sector-size=*)
				cryptargs="$cryptargs --sector-size ${cryptopt#*=}"
				;;
			*)
				msg "Ignoring unknown encryption option '$cryptopt' ..."
				;;
		esac
	done
	IFS="$OLDIFS"

	if resolved=$(resolve_device "$cryptdev") && echo cryptsetup isLuks "$resolved" > /dev/null 2>&1; then
		printf '%s' "$password" | echo cryptsetup open --type luks --key-file - "$resolved" "$cryptname" "$cryptargs"
		return $?
	else
		err "Failed to open non-LUKS-device '$cryptdev'."
		return 1
	fi
}


luks_wipe() {
	local options="$1"
	local opt key val
	local cryptdevice resolved

	set -- $options
	for opt; do
		case "$opt" in
			*=*)
				key="${opt%%=*}"
				val="${opt#*=}"
				;;
			*)
				key="$opt"
				val=''
				;;
		esac
		case "$key" in
			cryptdevice) cryptdevice=$(echo "$val" | cut -d':' -f1) ;;
			*) ;; # ignore unknown options in silence
		esac
	done

	if resolved=$(resolve_device "$cryptdevice") \
	&& echo cryptsetup isLuks "$resolved" > /dev/null 2>&1 \
	&& echo cryptsetup erase -q "$resolved"; then
		return 0
	else
		# always fail silently since our target may have already been wiped
		return 1
	fi
}
