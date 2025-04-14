#!/bin/sh
# 99-custom.sh 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom.sh
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
uci set firewall.@zone[1].input='ACCEPT'

# 设置主机名映射，解决安卓原生 TV 无法联网的问题
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# 检查配置文件pppoe-settings是否存在 该文件由build.sh动态生成
SETTINGS_FILE="/etc/config/pppoe-settings"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "PPPoE settings file not found. Skipping." >> $LOGFILE
else
   # 读取pppoe信息($enable_pppoe、$pppoe_account、$pppoe_password)
   . "$SETTINGS_FILE"
fi

# 配置网络接口为DHCP（动态适配接口名称）
INTERFACE=$(uci show network.@interface[-1](@ref).ifname 2>/dev/null | cut -d"'" -f2)
if [ -z "$INTERFACE" ]; then
    uci batch <<-EOF
        add network interface
        set network.@interface[-1](@ref).proto='dhcp'
        commit network
    EOF
else
    uci batch <<-EOF
        set network.@interface[-1](@ref).proto='dhcp'
        commit network
    EOF
fi

# 设置所有网口可访问网页终端
uci delete ttyd.@ttyd[0].interface

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit

# 设置时区（检查时区有效性）
if ! uci batch <<-EOF; then
    echo "Invalid timezone!" >&2
    exit 1
fi
    set system.@system[0](@ref).zonename='Asia/Shanghai'
    commit system
EOF

# 设置默认语言为中文
uci batch <<-EOF
    set luci.main.lang='zh_cn'
    commit luci
EOF

# 调整Argon主题（动态检测配置节点）
if uci show argon.@theme[0](@ref).mode >/dev/null 2>&1; then
    uci batch <<-EOF
        set argon.@theme[0](@ref).mode='light'
        commit argon
    EOF
fi


# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by 朽木"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

exit 0
