.PHONY: install-mkinitcpio

install-mkinitcpio:
	install -v -m 644 -T mkinitcpio/install.sh /usr/lib/initcpio/install/duress
	install -v -m 644 -T mkinitcpio/runscript.sh /usr/lib/initcpio/hooks/duress
	install -v -m 755 -T duress-mkconfig.sh /usr/local/bin/duress-mkconfig
