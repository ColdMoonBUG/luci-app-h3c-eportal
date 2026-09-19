# luci-app-nbtverify (H3C eportal / 海君 适配)

LuCI2 界面 + procd 托管的校园网自动认证客户端。基于 [nbtca/nbtverify](https://github.com/nbtca/nbtverify)（Go）二次开发，本仓库把它打包成适配 **ImmortalWrt / OpenWrt LuCI2** 的 IPK，并把认证流程从上游的"卓智 zportal"改成了 **H3C eportal（海君门户）**。

当配置的检测地址（Ping URL）掉线（被门户劫持、返回跳转脚本）时，自动用网页填好的账号密码完成 H3C eportal 认证；在线时保持静默，每 30 秒才重试一次，避免触发验证码/防暴力破解。

## 特性

- **LuCI2 JS 页面**（`menu.d` + view JS），服务 → NBT Verify
- **procd 托管**：开机自启、respawn、配置变更自动 reload
- 网页填写校园网账号、密码、移动端模式、Ping 地址
- 密码写入 `/var/run`（tmpfs）0600 权限，不落 `/etc`
- 登录成功后固定 30 秒退避，不会一秒钟刷十几个请求把服务器惹毛
- 同一条日志最多打 3 次，之后静默，不刷屏
- 干净 postinst/prerm，无硬编码测试 IP

## 适配的门户

H3C eportal（海君）手机端登录页，典型流程：

1. GET 检测地址 → 被 302 到 `/eportal/index.jsp?wlanuserip=...&...`（参数是哈希过的一次性令牌，JSESSIONID 种在 `Path=/eportal`）
2. 解析登录页后，**不提交页面上的 `haiJunForm`**（那个 form 只在"首次登录需改密码"时用），而是调用浏览器里 `AuthInterFace.js` 的 AJAX 接口：
   - `POST /eportal/InterFace.do?method=login`
   - `Content-Type: application/x-www-form-urlencoded; charset=UTF-8`
   - body：`userId=<双重URL编码用户名>&password=<双重URL编码密码>&service=&queryString=<双重URL编码原查询串>&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false`
3. 响应是 JS 对象 `{result:"success", message, userIndex, keepaliveInterval}`

> 上游默认走卓智 `/zportal/login/do`，对 H3C 门户会一直 404 或返回"您未认证或已经掉线"。本包的二进制已按上述流程改写。

## 目录结构

```
Makefile                        OpenWrt/ImmortalWrt SDK 打包（files/ 直装，无需 Go 工具链）
control/                        IPK 元数据与脚本（手工打包用）
files/
  etc/config/nbtverify          UCI 配置
  etc/init.d/nbtverify          procd init 脚本
  usr/bin/nbtverify             aarch64 静态二进制（Go, linux/arm64）
  usr/share/luci/menu.d/         LuCI2 菜单
  usr/share/rpcd/acl.d/         rpcd 权限
  www/luci-static/resources/view/nbtverify/status.js   LuCI2 视图
tools/
  build-aarch64.ps1             交叉编译 Go 二进制（GOOS=linux GOARCH=arm64）
  build_ipk.py                  不依赖 SDK 手工装配 IPK
```

## 构建

### 本地直接打包（无需 SDK）

```powershell
# 1. 交叉编译二进制（需要 Go；已有二进制可跳过）
$env:GOOS='linux'; $env:GOARCH='arm64'; $env:CGO_ENABLED='0'
go build -trimpath -ldflags '-s -w' -o nbtverify-aarch64 .
copy nbtverify-aarch64 files\usr\bin\nbtverify

# 2. 装配 IPK
python tools\build_ipk.py
# 输出: bin\luci-app-nbtverify_1.0.8-1_aarch64_cortex-a53.ipk
```

### ImmortalWrt SDK

```sh
cp -a luci-app-nbtverify openwrt-sdk/package/
cd openwrt-sdk
./scripts/feeds update -a && ./scripts/feeds install -a
make package/luci-app-nbtverify/compile V=s
```

## 安装

```sh
opkg install luci-app-nbtverify_1.0.8-1_aarch64_cortex-a53.ipk
```

LuCI → **服务 → NBT Verify** 填账号密码并启用，或直接改 `/etc/config/nbtverify`：

```
config server
    option username '学号'
    option password '密码'
    option enabled '1'
    option mobile '1'
    option ping 'http://10.147.103.3/'
```

## 手动调试

```sh
nbtverify -c /var/run/nbtverify/server.json login   # 手动认证一次
logread | grep nbtverify                              # 看日志
cat /var/run/nbtverify/login-response.dump           # 看门户原始响应
```

## 上游

- 二进制源码基线：https://github.com/nbtca/nbtverify （已在本地改写成 H3C eportal 流程）
- 本仓库初始重构：https://github.com/nbtca/luci-app-nbtverify/pull/1
