# Feed integration

本仓库是一个标准的 OpenWrt 源码包（`luci-app-nbtverify`），二进制直接随 `files/` 安装，
不需要额外工具链。

## 在完整源码树中使用

把以下内容加入 `feeds.conf`：

```text
src-git nbtverify https://github.com/nbtca/luci-app-nbtverify.git
```

安装 feed 并选择包：

```sh
./scripts/feeds update nbtverify
./scripts/feeds install -a -p nbtverify
echo 'CONFIG_PACKAGE_luci-app-nbtverify=m' >> .config
make defconfig
```

构建：

```sh
make package/luci-app-nbtverify/compile V=s
```

产物位于 `bin/packages/aarch64_cortex-a53/luci/luci-app-nbtverify_1.0.1-1_aarch64_cortex-a53.ipk`。

## 在 SDK 中使用（推荐）

```sh
# 下载对应目标的 SDK，例如 ImmortalWrt 24.10.2 / mediatek/filogic：
#   https://downloads.immortalwrt.org/releases/24.10.2/targets/mediatek/filogic/
#   immortalwrt-sdk-24.10.2-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst
cp -a luci-app-nbtverify openwrt-sdk/package/
cd openwrt-sdk
./scripts/feeds update -a && ./scripts/feeds install -a
echo 'CONFIG_PACKAGE_luci-app-nbtverify=m' >> .config
make defconfig
make package/luci-app-nbtverify/compile V=s
```

## 依赖

- `luci-base`：LuCI2 JS 运行时
- `jshn`：init 脚本生成运行时 JSON 配置
