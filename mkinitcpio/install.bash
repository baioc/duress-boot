#!/bin/bash

build() {
	add_file "/etc/duress.conf"
	add_runscript
}

help() {
	cat <<HELPEOF
This hook complements the built-in encrypt hook with a password-driven action
selector. In other words, the user will be prompted for a password at boot, and
depending on what they type in a different action will be executed. This allows
for booting into decoy systems or wiping data when booting under duress.

Users should configure /etc/duress.conf with the duress-mkconfig tool, then
regenerate the initramfs so that the configuration table is actually loaded.
This hook should always be loaded after the encrypt hook in the HOOKS array.
HELPEOF
}
