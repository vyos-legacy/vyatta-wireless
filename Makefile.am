cfgdir = $(datadir)/vyatta-cfg/templates
opdir = $(datadir)/vyatta-op/templates
share_perl5dir = /opt/vyatta/share/perl5/Vyatta/Wireless

sbin_SCRIPTS = scripts/vyatta-hostapd

bin_SCRIPTS = scripts/vyatta-show-wireless.pl

share_perl5_DATA = lib/Vyatta/Wireless/Hostapd.pm


cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
