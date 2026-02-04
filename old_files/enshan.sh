#!/bin/sh

# 生成0-900秒的随机数（15分钟=900秒）
DELAY=$((RANDOM % 901))
echo "将在 $DELAY 秒后执行..."
sleep $DELAY

# 配置文件路径
CONFIG_FILE="config.json"

# 调试文件路径（保存到当前目录）
DEBUG_DIR="./debug"
DEBUG_FILE="$DEBUG_DIR/enshan_debug.html"
SIGN_RESPONSE_FILE="$DEBUG_DIR/enshan_sign_response.html"
AFTER_SIGN_FILE="$DEBUG_DIR/enshan_after_sign.html"
CREDIT_FILE="$DEBUG_DIR/enshan_credit.html"
COOKIE_FILE="$DEBUG_DIR/enshan_cookies.txt"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件 $CONFIG_FILE 不存在！"
    exit 1
fi

# 检查必要的工具是否安装
if ! type jq &> /dev/null; then
    echo "jq 未安装，请先安装 jq！"
    exit 1
fi

# 从配置文件中读取配置信息
ENSHAN_COOKIE=$(jq -r '.ENSHAN[0].cookie' "$CONFIG_FILE")
PUSHPLUS_TOKEN=$(jq -r '.PUSHPLUS_TOKEN' "$CONFIG_FILE")
USER_UID=$(jq -r '.USER_UID' "$CONFIG_FILE")

# 检查配置信息是否存在
if [ -z "$ENSHAN_COOKIE" ]; then
    echo "未找到 EnShan Cookie，请检查 config.json 文件！"
    exit 1
fi

if [ -z "$PUSHPLUS_TOKEN" ] || [ "$PUSHPLUS_TOKEN" = "null" ]; then
    echo "未找到 PUSHPLUS_TOKEN，请检查 config.json 文件！"
    exit 1
fi

if [ -z "$USER_UID" ] || [ "$USER_UID" = "null" ]; then
    echo "未找到 USER_UID，请检查 config.json 文件！"
    exit 1
fi

# 创建调试目录
mkdir -p "$DEBUG_DIR"

# 清理函数
cleanup() {
    rm -f "$COOKIE_FILE"
}
trap cleanup EXIT

# 从页面提取签到信息
extract_sign_info() {
    local page_content="$1"
    local today_points=""
    local continuous_days=""
    local total_days=""
    
    # 提取今日积分
    today_points=$(echo "$page_content" | grep -oE '今日积分[^<]*' | grep -oE '[0-9]+' | head -1)
    if [ -z "$today_points" ]; then
        today_points=$(echo "$page_content" | grep -oE 'erqd-current-point[^>]*>[^<]*' | sed 's/.*>//' | head -1)
    fi
    
    # 提取连续签到天数
    continuous_days=$(echo "$page_content" | grep -oE '连续签到[^<]*' | grep -oE '[0-9]+' | head -1)
    if [ -z "$continuous_days" ]; then
        continuous_days=$(echo "$page_content" | grep -oE 'erqd-continuous-days[^>]*>[^<]*' | sed 's/.*>//' | head -1)
    fi
    
    # 提取总签到天数
    total_days=$(echo "$page_content" | grep -oE '总签到天数[^<]*' | grep -oE '[0-9]+' | head -1)
    if [ -z "$total_days" ]; then
        total_days=$(echo "$page_content" | grep -oE 'erqd-total-days[^>]*>[^<]*' | sed 's/.*>//' | head -1)
    fi
    
    # 如果都没找到，返回默认值
    today_points=${today_points:-"未知"}
    continuous_days=${continuous_days:-"未知"}
    total_days=${total_days:-"未知"}
    
    echo "$today_points|$continuous_days|$total_days"
}

# 从积分页面提取积分信息
extract_credit_info() {
    local page_content="$1"
    local total_points=""
    local contribution=""
    local enshan_coin=""

    # 将换行符替换为空格，以便匹配跨行的内容
    page_content=$(echo "$page_content" | tr '\n' ' ')

    # 方法1: 从user_box中提取积分信息
    # 先提取user_box的整个HTML部分
    local user_box_html=$(echo "$page_content" | grep -oE '<div class="user_box cl"[^>]*>.*</div>' | head -1)

    if [ -n "$user_box_html" ]; then
        # 从user_box_html中提取总积分
        total_points=$(echo "$user_box_html" | grep -oE '<span>[0-9]+</span>积分' | grep -oE '[0-9]+')
        # 从user_box_html中提取贡献分
        contribution=$(echo "$user_box_html" | grep -oE '<span>[0-9]+ 分</span>贡献' | grep -oE '[0-9]+')
        # 从user_box_html中提取恩山币
        enshan_coin=$(echo "$user_box_html" | grep -oE '<span>[0-9]+ 币</span>恩山币' | grep -oE '[0-9]+')
    fi

    # 如果都没找到，返回默认值
    total_points=${total_points:-"未知"}
    contribution=${contribution:-"未知"}
    enshan_coin=${enshan_coin:-"未知"}

    echo "$total_points|$contribution|$enshan_coin"
}

# 获取积分页面内容
get_credit_page() {
    # 使用从配置文件读取的UID
    local credit_url="https://www.right.com.cn/forum/home.php?mod=space&uid=$USER_UID&do=profile&mycenter=1&mobile=2"
    
    echo "尝试访问积分页面: $credit_url"
    local response=$(curl -s -L "$credit_url" \
      -b "$COOKIE_FILE" \
      -c "$COOKIE_FILE" \
      --compressed \
      -H 'User-Agent: Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36' \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
      -H 'Accept-Language: zh-CN,zh;q=0.9' \
      -H 'Accept-Encoding: gzip, deflate, br, zstd' \
      -H 'Referer: https://www.right.com.cn/forum/forum.php' \
      -H 'DNT: 1' \
      -H 'Connection: keep-alive' \
      -H 'Upgrade-Insecure-Requests: 1' \
      -H 'Sec-Fetch-Dest: document' \
      -H 'Sec-Fetch-Mode: navigate' \
      -H 'Sec-Fetch-Site: same-origin' \
      -H 'Sec-Fetch-User: ?1')
    
    echo "$response"
}

# 访问积分记录页面触发数据更新
refresh_credit_log() {
    echo "步骤4.5: 访问积分记录页面触发数据更新..."
    local credit_log_url="https://www.right.com.cn/forum/home.php?mod=spacecp&ac=credit&op=log&mobile=2"
    
    echo "访问积分记录页面: $credit_log_url"
    local response=$(curl -s -L "$credit_log_url" \
      -b "$COOKIE_FILE" \
      -c "$COOKIE_FILE" \
      --compressed \
      -H 'User-Agent: Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36' \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
      -H 'Accept-Language: zh-CN,zh;q=0.9' \
      -H 'Accept-Encoding: gzip, deflate, br, zstd' \
      -H 'Referer: https://www.right.com.cn/forum/forum.php' \
      -H 'DNT: 1' \
      -H 'Connection: keep-alive' \
      -H 'Upgrade-Insecure-Requests: 1' \
      -H 'Sec-Fetch-Dest: document' \
      -H 'Sec-Fetch-Mode: navigate' \
      -H 'Sec-Fetch-Site: same-origin' \
      -H 'Sec-Fetch-User: ?1')
    
    # 等待5秒确保数据更新
    echo "等待5秒确保数据更新..."
    sleep 5
}

# 获取签到页面内容
get_sign_page() {
    local url="$1"
    local response=$(curl -s -L "$url" \
      -b "$COOKIE_FILE" \
      -c "$COOKIE_FILE" \
      --compressed \
      -H 'User-Agent: Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36' \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
      -H 'Accept-Language: zh-CN,zh;q=0.9' \
      -H 'Accept-Encoding: gzip, deflate, br, zstd' \
      -H 'Referer: https://www.right.com.cn/forum/forum.php' \
      -H 'DNT: 1' \
      -H 'Connection: keep-alive' \
      -H 'Upgrade-Insecure-Requests: 1' \
      -H 'Sec-Fetch-Dest: document' \
      -H 'Sec-Fetch-Mode: navigate' \
      -H 'Sec-Fetch-Site: same-origin' \
      -H 'Sec-Fetch-User: ?1')
    
    echo "$response"
}

# 使用cookie jar的CURL签到函数
curl_sign_enshan() {
    echo "使用CURL方式进行签到（使用Cookie Jar）..."
    
    # 初始化cookie文件
    echo "# Netscape HTTP Cookie File" > "$COOKIE_FILE"
    echo "# This file was generated by enshan_sign.sh" >> "$COOKIE_FILE"
    
    # 将初始cookie添加到文件
    echo "$ENSHAN_COOKIE" | tr ';' '\n' | while read -r cookie; do
        if [ -n "$(echo "$cookie" | tr -d ' ')" ]; then
            name=$(echo "$cookie" | cut -d'=' -f1 | xargs)
            value=$(echo "$cookie" | cut -d'=' -f2- | xargs)
            if [ -n "$name" ] && [ -n "$value" ]; then
                # 格式: domain flag path secure expiration name value
                echo -e ".right.com.cn\tTRUE\t/\tFALSE\t0\t$name\t$value" >> "$COOKIE_FILE"
            fi
        fi
    done
    
    # 使用移动端页面
    CHECK_URL="https://www.right.com.cn/forum/erling_qd-sign_in_m.html"
    SIGN_URL="https://www.right.com.cn/forum/plugin.php?id=erling_qd:action&action=sign"
    
    echo "步骤1: 获取签到页面信息..."
    local check_response=$(get_sign_page "$CHECK_URL")
    
    # 保存页面内容到调试文件
    echo "$check_response" > "$DEBUG_FILE"
    
    # 检查页面是否正常加载
    if [ -z "$check_response" ]; then
        echo "错误: 页面内容为空，可能是网络问题或Cookie失效"
        return 1
    fi
    
    # 检查是否已签到（从页面内容判断）
    if echo "$check_response" | grep -q "连续签到.*[0-9].*天" && ! echo "$check_response" | grep -q "立即签到"; then
        local sign_info=$(extract_sign_info "$check_response")
        local today_points=$(echo "$sign_info" | cut -d'|' -f1)
        local continuous_days=$(echo "$sign_info" | cut -d'|' -f2)
        local total_days=$(echo "$sign_info" | cut -d'|' -f3)
        echo "今日已签到，连续签到 $continuous_days 天"
        echo "今日积分：$today_points；连续签到：$continuous_days 天；总签到天数：$total_days 天"
        
        # 刷新积分记录页面确保数据更新
        refresh_credit_log
        
        # 获取积分信息
        echo "步骤5: 获取积分信息..."
        local credit_response=$(get_credit_page)
        echo "$credit_response" > "$CREDIT_FILE"
        
        local credit_info=$(extract_credit_info "$credit_response")
        local total_points=$(echo "$credit_info" | cut -d'|' -f1)
        local contribution=$(echo "$credit_info" | cut -d'|' -f2)
        local enshan_coin=$(echo "$credit_info" | cut -d'|' -f3)
        
        echo "积分详细信息："
        echo "总积分：$total_points"
        echo "贡献分：$contribution 分"
        echo "恩山币：$enshan_coin 币"
        
        # 返回详细信息用于推送
        echo "SUCCESS|$today_points|$continuous_days|$total_days|$total_points|$contribution|$enshan_coin"
        return 0
    fi

    # 尝试多种方式提取formhash
    echo "步骤2: 尝试提取formhash..."
    local formhash=""
    
    # 方法1: 从JavaScript变量提取（这是正确的方法）
    formhash=$(echo "$check_response" | grep -oE "var FORMHASH = '[a-fA-F0-9]+';" | cut -d"'" -f2)
    
    # 方法2: 从formhash参数提取
    if [ -z "$formhash" ]; then
        formhash=$(echo "$check_response" | grep -oE 'formhash=[a-fA-F0-9]+' | cut -d'=' -f2 | head -n1)
    fi
    
    # 方法3: 从隐藏输入框提取
    if [ -z "$formhash" ]; then
        formhash=$(echo "$check_response" | grep -oE 'name="formhash" value="[a-fA-F0-9]+"' | cut -d'"' -f4)
    fi
    
    # 方法4: 从签到链接提取
    if [ -z "$formhash" ]; then
        formhash=$(echo "$check_response" | grep -oE 'qiandao&formhash=[a-fA-F0-9]+' | cut -d'=' -f2 | head -n1)
    fi
    
    if [ -z "$formhash" ]; then
        echo "错误: 无法获取formhash"
        echo "页面内容已保存到 $DEBUG_FILE"
        return 1
    fi
    
    echo "成功获取formhash: $formhash"
    
    echo "步骤3: 执行签到请求..."
    local sign_response=$(curl -s -X POST "$SIGN_URL" \
      -b "$COOKIE_FILE" \
      -c "$COOKIE_FILE" \
      --compressed \
      -H 'User-Agent: Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36' \
      -H 'Accept: application/json, text/javascript, */*; q=0.01' \
      -H 'Accept-Language: zh-CN,zh;q=0.9' \
      -H 'Accept-Encoding: gzip, deflate, br, zstd' \
      -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
      -H "Referer: $CHECK_URL" \
      -H 'X-Requested-With: XMLHttpRequest' \
      -H 'Origin: https://www.right.com.cn' \
      -H 'DNT: 1' \
      -H 'Connection: keep-alive' \
      -H 'Sec-Fetch-Dest: empty' \
      -H 'Sec-Fetch-Mode: cors' \
      -H 'Sec-Fetch-Site: same-origin' \
      --data-raw "formhash=$formhash")
    
    # 保存签到响应到文件
    echo "$sign_response" > "$SIGN_RESPONSE_FILE"
    
    # 检查签到结果
    if echo "$sign_response" | grep -q '"success":true'; then
        # 从JSON响应中提取详细信息
        local message=$(echo "$sign_response" | jq -r '.message // empty' 2>/dev/null || echo "签到成功")
        echo "签到成功: $message"
        
        # 步骤4: 重新加载页面获取详细的签到信息
        echo "步骤4: 获取签到后的详细信息..."
        local after_sign_response=$(get_sign_page "$CHECK_URL")
        echo "$after_sign_response" > "$AFTER_SIGN_FILE"
        
        local sign_info=$(extract_sign_info "$after_sign_response")
        local today_points=$(echo "$sign_info" | cut -d'|' -f1)
        local continuous_days=$(echo "$sign_info" | cut -d'|' -f2)
        local total_days=$(echo "$sign_info" | cut -d'|' -f3)
        
        echo "签到详细信息："
        echo "今日积分：$today_points"
        echo "连续签到：$continuous_days 天"
        echo "总签到天数：$total_days 天"
        
        # 刷新积分记录页面确保数据更新
        refresh_credit_log
        
        # 步骤5: 获取积分信息
        echo "步骤5: 获取积分信息..."
        local credit_response=$(get_credit_page)
        echo "$credit_response" > "$CREDIT_FILE"
        
        local credit_info=$(extract_credit_info "$credit_response")
        local total_points=$(echo "$credit_info" | cut -d'|' -f1)
        local contribution=$(echo "$credit_info" | cut -d'|' -f2)
        local enshan_coin=$(echo "$credit_info" | cut -d'|' -f3)
        
        echo "积分详细信息："
        echo "总积分：$total_points"
        echo "贡献分：$contribution 分"
        echo "恩山币：$enshan_coin 币"
        
        # 返回详细信息用于推送
        echo "SUCCESS|$today_points|$continuous_days|$total_days|$total_points|$contribution|$enshan_coin"
        return 0
    elif echo "$sign_response" | grep -q '"success":false'; then
        local error_msg=$(echo "$sign_response" | jq -r '.message // empty' 2>/dev/null || echo "未知错误")
        echo "签到失败: $error_msg"
        return 1
    elif echo "$sign_response" | grep -q "您今天已经签到"; then
        echo "签到成功（已签到）"
        
        # 获取详细信息
        local sign_info=$(extract_sign_info "$check_response")
        local today_points=$(echo "$sign_info" | cut -d'|' -f1)
        local continuous_days=$(echo "$sign_info" | cut -d'|' -f2)
        local total_days=$(echo "$sign_info" | cut -d'|' -f3)
        
        echo "今日积分：$today_points；连续签到：$continuous_days 天；总签到天数：$total_days 天"
        
        # 刷新积分记录页面确保数据更新
        refresh_credit_log
        
        # 获取积分信息
        echo "步骤4: 获取积分信息..."
        local credit_response=$(get_credit_page)
        echo "$credit_response" > "$CREDIT_FILE"
        
        local credit_info=$(extract_credit_info "$credit_response")
        local total_points=$(echo "$credit_info" | cut -d'|' -f1)
        local contribution=$(echo "$credit_info" | cut -d'|' -f2)
        local enshan_coin=$(echo "$credit_info" | cut -d'|' -f3)
        
        echo "积分详细信息："
        echo "总积分：$total_points"
        echo "贡献分：$contribution 分"
        echo "恩山币：$enshan_coin 币"
        
        echo "SUCCESS|$today_points|$continuous_days|$total_days|$total_points|$contribution|$enshan_coin"
        return 0
    else
        echo "签到失败，响应内容已保存到 $SIGN_RESPONSE_FILE"
        return 1
    fi
}

# PUSHPLUS 推送函数
push_pushplus() {
    local message="$1"
    echo "推送通知到 PUSHPLUS..."
    
    local json_data=$(jq -n \
        --arg token "$PUSHPLUS_TOKEN" \
        --arg title "恩山签到结果" \
        --arg content "$message" \
        '{token: $token, title: $title, content: $content}')
    
    local response=$(curl -s -X POST "https://www.pushplus.plus/send" \
        -H "Content-Type: application/json" \
        -d "$json_data")
    
    if echo "$response" | jq -e '.code == 200' > /dev/null; then
        echo "通知已发送到 PUSHPLUS！"
    else
        echo "通知发送失败，错误信息: $(echo "$response" | jq -r '.msg')"
    fi
}

# 检查Cookie有效性
check_cookie_validity() {
    echo "检查Cookie有效性..."
    local test_url="https://www.right.com.cn/forum/forum.php"
    
    # 创建临时cookie文件
    local temp_cookie=$(mktemp)
    echo "# Netscape HTTP Cookie File" > "$temp_cookie"
    echo "$ENSHAN_COOKIE" | tr ';' '\n' | while read -r cookie; do
        if [ -n "$(echo "$cookie" | tr -d ' ')" ]; then
            name=$(echo "$cookie" | cut -d'=' -f1 | xargs)
            value=$(echo "$cookie" | cut -d'=' -f2- | xargs)
            if [ -n "$name" ] && [ -n "$value" ]; then
                echo -e ".right.com.cn\tTRUE\t/\tFALSE\t0\t$name\t$value" >> "$temp_cookie"
            fi
        fi
    done
    
    local response=$(curl -s -I -L "$test_url" \
        -b "$temp_cookie" \
        -c "$temp_cookie" \
        -H "User-Agent: Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36")
    
    rm -f "$temp_cookie"
    
    if echo "$response" | grep -q "200 OK"; then
        echo "Cookie有效性检查: 通过"
        return 0
    else
        echo "Cookie有效性检查: 失败"
        return 1
    fi
}

# 生成失败推送消息
generate_failure_message() {
    local error_output="$1"
    local message="签到失败了，"
    
    if echo "$error_output" | grep -q "无法获取formhash"; then
        message+="原因是无法获取formhash，可能是Cookie失效或页面结构变化，请及时更新Cookie。"
    elif echo "$error_output" | grep -q "Cookie失效"; then
        message+="原因是Cookie失效，请及时更新Cookie。"
    elif echo "$error_output" | grep -q "页面内容为空"; then
        message+="原因是网络问题或Cookie失效，请检查网络连接并更新Cookie。"
    elif echo "$error_output" | grep -q "签到失败"; then
        message+="原因未知，请检查网络连接或稍后重试。"
    else
        message+="请检查脚本日志获取详细错误信息。"
    fi
    
    echo "$message"
}

# 主逻辑
main() {
    echo "开始恩山论坛签到..."
    
    # 首先检查Cookie有效性
    if ! check_cookie_validity; then
        local error_msg="签到失败：Cookie可能已失效，请更新config.json"
        echo "$error_msg"
        push_pushplus "$error_msg"
        exit 1
    fi
    
    # 主要使用CURL方式
    echo "=== 使用CURL方式签到 ==="
    # 使用临时文件来捕获curl_sign_enshan的输出
    local temp_output=$(mktemp)
    local curl_status=0
    curl_sign_enshan > "$temp_output" 2>&1 || curl_status=$?
    local curl_result=$(cat "$temp_output")
    rm -f "$temp_output"
    
    echo "$curl_result"
    
    if [ $curl_status -eq 0 ]; then
        # 提取成功信息
        local success_line=$(echo "$curl_result" | grep "^SUCCESS|")
        if [ -n "$success_line" ]; then
            local today_points=$(echo "$success_line" | cut -d'|' -f2)
            local continuous_days=$(echo "$success_line" | cut -d'|' -f3)
            local total_days=$(echo "$success_line" | cut -d'|' -f4)
            local total_points=$(echo "$success_line" | cut -d'|' -f5)
            local contribution=$(echo "$success_line" | cut -d'|' -f6)
            local enshan_coin=$(echo "$success_line" | cut -d'|' -f7)
            
            local push_message="签到成功！<br>今日积分：$today_points <br>连续签到：$continuous_days 天 <br>总签到天数：$total_days 天 <br>总积分：$total_points <br>贡献分：$contribution 分 <br>恩山币：$enshan_coin 币 "
        else
            # 如果没有SUCCESS行，尝试从输出中提取信息
            local today_points=$(echo "$curl_result" | grep -oE '今日积分：[0-9]+' | grep -oE '[0-9]+' | head -1)
            local continuous_days=$(echo "$curl_result" | grep -oE '连续签到：[0-9]+' | grep -oE '[0-9]+' | head -1)
            local total_days=$(echo "$curl_result" | grep -oE '总签到天数：[0-9]+' | grep -oE '[0-9]+' | head -1)
            local total_points=$(echo "$curl_result" | grep -oE '总积分：[0-9]+' | grep -oE '[0-9]+' | head -1)
            local contribution=$(echo "$curl_result" | grep -oE '贡献分：[0-9]+' | grep -oE '[0-9]+' | head -1)
            local enshan_coin=$(echo "$curl_result" | grep -oE '恩山币：[0-9]+' | grep -oE '[0-9]+' | head -1)
            
            today_points=${today_points:-"未知"}
            continuous_days=${continuous_days:-"未知"}
            total_days=${total_days:-"未知"}
            total_points=${total_points:-"未知"}
            contribution=${contribution:-"未知"}
            enshan_coin=${enshan_coin:-"未知"}
            
            local push_message="签到成功！<br>今日积分：$today_points <br>连续签到：$continuous_days 天 <br>总签到天数：$total_days 天 <br>总积分：$total_points <br>贡献分：$contribution 分 <br>恩山币：$enshan_coin 币 "
        fi
        push_pushplus "$push_message"
    else
        echo "CURL方式失败，错误详情已记录"
        echo "调试文件保存在 $DEBUG_DIR 目录"
        local failure_message=$(generate_failure_message "$curl_result")
        push_pushplus "$failure_message"
    fi
}

# 执行主逻辑
main
