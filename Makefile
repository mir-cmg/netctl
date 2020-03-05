export VERSION = 1.20

PKG_CONFIG ?= pkg-config

SHELL=/bin/bash

sd_var = $(shell $(PKG_CONFIG) --variable=systemd$(1) systemd)
systemdsystemconfdir = $(call sd_var,systemconfdir)
systemdsystemunitdir = $(call sd_var,systemunitdir)

.PHONY: install tarball pkgbuild upload clean

install:
	# Documentation
	$(MAKE) -C docs install
	# Configuration files
	install -d $(DESTDIR)/etc/netctl/{examples,hooks,interfaces}
	install -m644 docs/examples/* $(DESTDIR)/etc/netctl/examples/
	# Libs
	install -d $(DESTDIR)/usr/lib/netctl/{connections,dhcp}
	install -m644 src/lib/{globals,interface,ip,rfkill,wpa} $(DESTDIR)/usr/lib/netctl/
	install -m644 src/lib/connections/* $(DESTDIR)/usr/lib/netctl/connections/
	install -m644 src/lib/dhcp/* $(DESTDIR)/usr/lib/netctl/dhcp/
	install -m755 src/lib/{auto.action,network} $(DESTDIR)/usr/lib/netctl/
	# Scripts
	install -d $(DESTDIR)/usr/bin
	sed -e "s|@systemdsystemconfdir@|$(systemdsystemconfdir)|g" \
	    -e "s|@systemdsystemunitdir@|$(systemdsystemunitdir)|g" \
	    src/netctl.in > $(DESTDIR)/usr/bin/netctl
	chmod 755 $(DESTDIR)/usr/bin/netctl
	install -m755 \
	    src/netctl-auto \
	    src/wifi-menu \
	    $(DESTDIR)/usr/bin/
	install -Dm755 src/ifplugd.action $(DESTDIR)/etc/ifplugd/netctl.action
	# Services
	install -d $(DESTDIR)$(systemdsystemunitdir)
	install -m644 services/*.service $(DESTDIR)$(systemdsystemunitdir)/

mirinstall:
	# Documentation
	$(MAKE) -C docs install
	# Configuration files
	install -d $(DESTDIR)/etc/netctl/{hooks,interfaces}
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/etc/netctl/hooks/robot.permission
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/etc/netctl/interfaces/robot.permission
	# Libs
	install -d $(DESTDIR)/usr/lib/netctl/{connections,dhcp}
	install -m644 src/lib/{globals,interface,ip,rfkill,wpa} $(DESTDIR)/usr/lib/netctl/
	for f in $(DESTDIR)/usr/lib/netctl/{globals,interface,ip,rfkill,wpa} ; do \
		echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > "$${f}.permission"; \
	done
	install -m644 src/lib/connections/wireless $(DESTDIR)/usr/lib/netctl/connections/
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/usr/lib/netctl/connections/wireless.permission
	install -m644 src/lib/dhcp/dhclient $(DESTDIR)/usr/lib/netctl/dhcp/
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/usr/lib/netctl/dhcp/dhclient.permission
	install -m755 src/lib/{auto.action,network} $(DESTDIR)/usr/lib/netctl/
	for f in $(DESTDIR)/usr/lib/netctl/{auto.action,network} ; do \
		echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"755\"\n}" > "$${f}.permission"; \
	done
	# Scripts
	install -d $(DESTDIR)/usr/bin
	install -m755 src/{netctl-auto,wifi-menu} $(DESTDIR)/usr/bin/
	for f in $(DESTDIR)/usr/bin/{netctl-auto,wifi-menu} ; do \
		echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"755\"\n}" > "$${f}.permission"; \
	done
	# Services
	install -d $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp2s0.device.wants/
	install -m644 services/netctl-auto@.service $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp2s0.device.wants/netctl-auto@wlp2s0.service
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp2s0.device.wants/netctl-auto@wlp2s0.service.permission
	install -d $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp58s0.device.wants/
	install -m644 services/netctl-auto@.service $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp58s0.device.wants/netctl-auto@wlp58s0.service
	echo -e "{\n \"group\": \"root\",\n \"owner\": \"root\",\n \"permission\": \"644\"\n}" > $(DESTDIR)/etc/systemd/system/sys-subsystem-net-devices-wlp58s0.device.wants/netctl-auto@wlp58s0.service.permission

tarball: netctl-$(VERSION).tar.xz
netctl-$(VERSION).tar.xz:
	$(MAKE) -B -C docs
	cp src/lib/globals{,.orig}
	sed -i "s|NETCTL_VERSION=.*|NETCTL_VERSION=$(VERSION)|" src/lib/globals
	git stash save -q
	git archive -o netctl-$(VERSION).tar --prefix=netctl-$(VERSION)/ stash
	git stash pop -q
	mv src/lib/globals{.orig,}
	tar --exclude-vcs --transform "s|^|netctl-$(VERSION)/|" --owner=root --group=root --mtime=./netctl-$(VERSION).tar -rf netctl-$(VERSION).tar docs/*.[1-8]
	xz netctl-$(VERSION).tar
	gpg --detach-sign $@

pkgbuild: PKGBUILD
PKGBUILD: netctl-$(VERSION).tar.xz netctl.install contrib/PKGBUILD.in
	sed -e "s|@pkgver@|$(VERSION)|g" \
	    -e "s|@md5sum@|$(shell md5sum $< | cut -d ' ' -f 1)|" \
	    -e "s|@md5sum.sig@|$(shell md5sum $<.sig | cut -d ' ' -f 1)|" \
	    $(lastword $^) > $@

netctl.install: contrib/netctl.install
	cp $< $@

upload: netctl-$(VERSION).tar.xz
	scp $< $<.sig sources.archlinux.org:/srv/ftp/other/packages/netctl

clean:
	$(MAKE) -C docs clean
	-@rm -vf netctl-*.tar.xz{,.sig} PKGBUILD netctl.install
