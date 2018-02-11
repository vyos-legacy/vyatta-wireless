cfgdir = $(datadir)/vyatta-cfg/templates
opdir = $(datadir)/vyatta-op/templates

sbin_SCRIPTS  = scripts/wireless-config.pl
sbin_SCRIPTS += scripts/wireless-hostapd.pl
sbin_SCRIPTS += scripts/hostapd-init
sbin_SCRIPTS += scripts/wireless-wpa_supplicant.pl
sbin_SCRIPTS += scripts/wpa_supplicant-init
sbin_SCRIPTS += scripts/vyos-wireless-cfg-regdom.py
sbin_SCRIPTS += scripts/vyos-wireless-op-regdom.py

bin_SCRIPTS = scripts/show-wireless.pl

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
