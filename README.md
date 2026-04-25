# ZTE F50 VPN Hotspot Route Fix Magisk Module

修复中兴 F50 安装 [VPN Hotspot](https://github.com/mygod/vpnhotspot) 使用以太网网络共享不生效的问题。

## 依赖

使用[UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS) root 中兴F50，并安装其自带的Magisk App 1e3edb88 (28103)

## 问题

中兴 F50 的以太网网络共享侧是 `br0` 网桥，不是普通 Android 以太网共享常见的 tether 接口 `eth0`。VPN Hotspot 能识别 VPN 上游为 `tun0`，但系统策略路由里 `main` 表的优先级更高。

F50内置的策略路由顺序：

```sh
9999:  from all lookup main
17800: from all iif br0 lookup tun0
```

`main` 中存在：

```sh
<VPN内网网段> dev sipa_eth0
```

部分 VPN 目标会先命中 `main`，从 `sipa_eth0` 出去。

## 修复

本模块不修改 iptables，只补一条 iproute2 策略路由规则。

`tun0` 存在且 `table tun0` 有路由时，执行以下 iproute2 命令：

```sh
ip rule add pref 9000 lookup tun0
ip route flush cache
```

`tun0` 消失时，执行以下 iproute2 命令：

```sh
ip rule del pref 9000 lookup tun0
ip route flush cache
```

假设 `table tun0` 只有分流路由，没有默认路由。

## 构建

```sh
./build.sh
```

产物：

```sh
dist/vpn-tun0-rule-fix.zip
```

## 验证

```sh
su -c 'ip rule'
su -c 'ip route get <VPN内网地址>'
su -c 'ip route get <VPN内网地址> from <下游设备地址> iif br0'
su -c 'ip route get <公网地址>'
```

预期：

```text
<VPN内网地址> -> dev tun0
<VPN内网地址> from <下游设备地址> iif br0 -> dev tun0
<公网地址> -> dev sipa_eth0
```
