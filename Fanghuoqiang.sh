#!/bin/bash
#================================================================
# “帝国UFW智能城防向导” (Debian版)
# 目标：自动侦测并以交互方式，安全地配置UFW防火墙
# 作者：Gemini & 舰队指挥官 張財多
#================================================================

# --- 彩色输出定义 ---
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
NC="\033[0m"

# --- 脚本主体 ---
echo -e "${BLUE}---[ 帝国UFW智能城防向导 (Debian版) 已启动 ]---${NC}"
echo "本向导将引导您安全地配置防火墙，请根据提示操作。"

# 1. 安装依赖工具 (UFW 和 iproute2/ss)
echo -e "\n${YELLOW}  [1/5] 正在检查并安装必要组件...${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y ufw iproute2 >/dev/null 2>&1
echo -e "${GREEN}✅ 组件就绪。${NC}"

# 2. 自动侦测SSH生命线端口
echo -e "\n${YELLOW}  [2/5] 正在自动侦测您的SSH生命线端口...${NC}"
SSH_PORT=$(ss -lntp | grep -E 'sshd?' | grep -o ':[0-9]*' | cut -d: -f2 | head -n 1)
if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
    echo -e "${YELLOW}⚠️ 未侦测到活动的SSH服务，将默认使用标准端口 22。${NC}"
fi
echo -e "${GREEN}✅ SSH生命线端口确认为: ${SSH_PORT}/tcp (将自动放行)${NC}"

# 3. 侦测其他所有正在使用的端口
echo -e "\n${YELLOW}  [3/5] 正在扫描帝国的所有活动端口...${NC}"
# 使用ss命令，提取所有TCP和UDP监听端口，并排除已知的SSH端口
DETECTED_PORTS=$(ss -lntu | grep 'LISTEN' | awk '{print $5}' | grep -o ':[0-9]*' | cut -d: -f2 | grep -v "^${SSH_PORT}$" | sort -u)

if [ -z "$DETECTED_PORTS" ]; then
    echo -e "${GREEN}✅ 除SSH外，未发现其他对外开放的端口。${NC}"
else
    echo -e "${GREEN}✅ 侦测到以下活动端口，请逐一确认是否放行：${NC}"
fi

# 4. 交互式确认端口
ALLOWED_PORTS=""
for PORT in $DETECTED_PORTS; do
    # 尝试找出使用该端口的进程名
    PROCESS_INFO=$(ss -lntup | grep ":${PORT} " | awk -F'"' '{print $2}' | head -n 1)
    if [ -n "$PROCESS_INFO" ]; then
        PROMPT_MSG="端口 ${YELLOW}${PORT}${NC} (由 ${BLUE}${PROCESS_INFO}${NC} 使用) 是否放行？"
    else
        PROMPT_MSG="端口 ${YELLOW}${PORT}${NC} 是否放行？"
    fi

    printf "    - ${PROMPT_MSG} (y/n): "
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        ALLOWED_PORTS="${ALLOWED_PORTS} ${PORT}"
        echo -e "      ${GREEN} -> 已加入放行列表。${NC}"
    else
        echo -e "      ${RED} -> 已设为阻止。${NC}"
    fi
done

# 5. 最终确认并执行
echo -e "\n${YELLOW}  [4/5] 请最终确认部署方案...${NC}"
echo "--------------------------------------------------"
echo -e "城防系统将执行以下操作："
echo -e "  - 默认策略: ${RED}拒绝所有入站${NC}, ${GREEN}允许所有出站${NC}"
echo -e "  - ${GREEN}永久放行 (生命线): ${SSH_PORT}/tcp (SSH)${NC}"

for PORT in $ALLOWED_PORTS; do
    echo -e "  - ${GREEN}本次放行 (用户授权): ${PORT} (TCP/UDP)${NC}"
done
echo "--------------------------------------------------"
printf "您是否确认应用以上规则并启动防火墙？ (y/n): "
read -r final_answer
if [ "$final_answer" != "y" ] && [ "$final_answer" != "Y" ]; then
    echo -e "${RED}操作已由用户取消。帝国城防维持现状。${NC}"
    exit 0
fi

echo -e "\n${YELLOW}  [5/5] 正在部署城防系统...${NC}"
# 重置以确保干净的环境
ufw --force reset >/dev/null 2>&1
# 应用规则
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow ${SSH_PORT}/tcp >/dev/null 2>&1
for PORT in $ALLOWED_PORTS; do
    ufw allow ${PORT} >/dev/null 2>&1
done
# 启动防火墙
echo "y" | ufw enable >/dev/null 2>&1
# 设置开机自启
systemctl enable ufw >/dev/null 2>&1

echo -e "\n${GREEN}=====================================================================${NC}"
echo -e "${GREEN}🎉 指挥官，帝国UFW城防系统已成功启动！${NC}"
echo -e "${GREEN}=====================================================================${NC}"
ufw status verbose