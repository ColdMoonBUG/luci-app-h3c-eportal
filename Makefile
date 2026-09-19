include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nbtverify
PKG_VERSION:=1.0.8
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=nbtca <https://github.com/nbtca>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-nbtverify
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=Campus network authentication client (NBTVerify)
	URL:=https://github.com/nbtca/luci-app-nbtverify
	DEPENDS:=+jshn +luci-base
endef

define Package/luci-app-nbtverify/description
	NBTVerify campus network authentication client with LuCI2 web interface.
	Detects an offline campus network via the configured ping URL and
	authenticates automatically. Binary is a statically linked aarch64 Go
	program built from https://github.com/nbtca/nbtverify (see tools/).
endef

define Package/luci-app-nbtverify/conffiles
/etc/config/nbtverify
endef

define Package/luci-app-nbtverify/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/nbtverify $(1)/usr/bin/nbtverify
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/nbtverify $(1)/etc/config/nbtverify
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/nbtverify $(1)/etc/init.d/nbtverify
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-app-nbtverify.json $(1)/usr/share/luci/menu.d/luci-app-nbtverify.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-nbtverify.json $(1)/usr/share/rpcd/acl.d/luci-app-nbtverify.json
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/nbtverify
	$(INSTALL_DATA) ./files/www/luci-static/resources/view/nbtverify/status.js $(1)/www/luci-static/resources/view/nbtverify/status.js
endef

$(eval $(call BuildPackage,luci-app-nbtverify))
