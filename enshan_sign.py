# -*- coding: utf-8 -*-
import json
import time
import os
import re
import random
import requests
from DrissionPage import ChromiumPage, ChromiumOptions

# ================= 配置区域 =================
CONFIG_FILE = "config.json"
# ===========================================

# 统一的 User-Agent
USER_AGENT = "Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36"

def random_wait():
    """随机倒数函数 (0-900秒)"""
    delay = random.randint(0, 900)
    print(f"🎲 随机延迟启动: 将在 {delay} 秒后开始执行任务...")
    time.sleep(delay)
    print("⏰ 倒计时结束，任务开始！")

def force_kill_chrome():
    """强制清理残留的浏览器进程 (环境自愈)"""
    print("🧹 正在清理残留的浏览器进程...")
    try:
        os.system("pkill -f chromium")
        os.system("pkill -f chrome")
        time.sleep(2) # 等待释放资源
    except:
        pass

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print(f"错误: 找不到 {CONFIG_FILE}")
        return None
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_cookie_to_config(new_cookie_str):
    try:
        data = load_config()
        if not data: return
        if "rHEX_2132_auth" not in new_cookie_str: return
        
        print("💾 正在更新 config.json 中的 Cookie...")
        data['cookie'] = new_cookie_str # 更新根目录cookie
        
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
        print("✅ Cookie 更新成功！")
    except Exception as e:
        print(f"❌ 保存 Cookie 失败: {str(e)}")

def push_pushplus(token, content):
    if not token:
        print("⚠️ 未配置 PUSHPLUS_TOKEN，跳过推送")
        return
        
    url = "https://www.pushplus.plus/send"
    data = {"token": token, "title": "恩山签到结果", "content": content}
    try:
        requests.post(url, json=data)
        print("📨 PushPlus 通知已发送")
    except Exception as e:
        print(f"❌ 推送失败: {e}")

def get_cookies_safe(page):
    try:
        ret = page.run_cdp('Network.getCookies')
        cookies_list = ret.get('cookies', [])
        return "; ".join([f"{item['name']}={item['value']}" for item in cookies_list])
    except Exception as e:
        print(f"❌ 获取 Cookie 异常: {e}")
        return ""

def extract_regex(pattern, text, default="0"):
    try:
        match = re.search(pattern, text)
        return match.group(1).strip() if match else default
    except:
        return default

def run_sign_in():
    # 1. 执行随机延迟
    random_wait()

    # 2. 读取配置
    config = load_config()
    if not config: return
    
    raw_cookie = config.get('cookie', '')
    push_token = config.get('PUSHPLUS_TOKEN', '')
    user_uid = config.get('USER_UID', '')
    
    if not raw_cookie or not user_uid:
        print("❌ 错误: config.json 配置缺失")
        return

    # 3. 初始化浏览器配置 (针对 Docker/青龙 深度优化)
    co = ChromiumOptions()
    co.set_argument('--no-sandbox')           # Linux root 运行必需
    co.set_argument('--disable-gpu')          # 禁用 GPU 加速
    co.set_argument('--disable-dev-shm-usage') # 解决 Docker 内存崩溃问题 (关键)
    co.set_argument('--headless=new')         # 新版无头模式 (关键)
    co.set_argument('--window-size=375,812')  # 手机尺寸
    
    # 自动识别路径
    if os.path.exists("/usr/bin/chromium-browser"):
        co.set_paths(browser_path="/usr/bin/chromium-browser")
    elif os.path.exists("/usr/bin/chromium"):
        co.set_paths(browser_path="/usr/bin/chromium")
    
    co.set_user_agent(user_agent=USER_AGENT)
    
    # 4. 尝试启动浏览器 (含重试机制)
    page = None
    for attempt in range(2):
        try:
            # 每次启动前先清理环境
            force_kill_chrome()
            page = ChromiumPage(co)
            break # 启动成功，跳出循环
        except Exception as e:
            print(f"⚠️ 浏览器启动失败 (第 {attempt+1} 次尝试): {e}")
            time.sleep(3)
    
    if not page:
        print("❌ 浏览器连续启动失败，放弃执行。")
        push_pushplus(push_token, "恩山脚本错误: 浏览器启动失败 (已尝试清理进程)。")
        return

    try:
        print("=== 开始执行恩山签到 (Python版 by Funseaon) ===")
        
        # 5. 访问主页 & 注入 Cookie
        print("1. 访问主页确立作用域...")
        page.get('https://www.right.com.cn/forum/forum.php?mobile=2')
        try: page.set.cookies(raw_cookie)
        except: pass
        
        print("2. 刷新页面并过盾...")
        page.refresh()
        time.sleep(5)
            
        title = page.title
        if "安全" in title or "验证" in title:
            print("🛡️ 检测到防火墙拦截，正在等待自动跳转...")
            time.sleep(15)

        # 6. 获取 Formhash
        print("3. 正在获取签到信息...")
        check_url = "https://www.right.com.cn/forum/erling_qd-sign_in_m.html"
        page.get(check_url)
        
        is_signed = False
        # 宽容获取 body 文本
        try:
            body_text = page.ele('tag:body').text
            if "连续签到" in body_text and "立即签到" not in body_text:
                is_signed = True
                print("ℹ️ 状态: 今天已经签到过了。")
        except:
            pass

        html = page.html
        formhash = extract_regex(r"var FORMHASH = '([0-9a-zA-Z]+)'", html, "")
        if not formhash:
            formhash = extract_regex(r'name="formhash" value="([0-9a-zA-Z]+)"', html, "")
            
        if not formhash and not is_signed:
            print("❌ 错误: 无法提取 formhash")
            push_pushplus(push_token, "恩山签到失败：无法获取 Formhash")
            return
        
        if formhash:
            print(f"🔑 获取 Formhash 成功: {formhash}")

        # 7. 执行签到 (JS 注入)
        sign_success = False
        sign_msg = "已签到"
        
        if not is_signed:
            sign_api = "https://www.right.com.cn/forum/plugin.php?id=erling_qd:action&action=sign"
            print("🚀 正在发送签到请求...")
            js_code = f"""
            return fetch("{sign_api}", {{
                method: "POST",
                headers: {{
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                    "X-Requested-With": "XMLHttpRequest"
                }},
                body: "formhash={formhash}"
            }}).then(response => response.json());
            """
            try:
                result = page.run_js(js_code)
                print(f"📥 签到接口返回: {result}")
                if result and (result.get('success') or "已经签到" in str(result)):
                    sign_success = True
                    sign_msg = result.get('message', '签到成功')
                else:
                    sign_msg = result.get('message', '未知错误') if result else "接口无响应"
            except Exception as js_err:
                print(f"❌ JS 执行异常: {js_err}")
                sign_success = False
                sign_msg = "JS执行失败或WAF拦截"
        else:
            sign_success = True

        # 8. 最终数据获取与推送
        if sign_success:
            print("4. 正在获取最终积分数据...")
            
            # 8.1 获取签到数据
            page.get(check_url)
            time.sleep(2)
            sign_html = page.html
            today_points = extract_regex(r'erqd-current-point[^>]*>(\d+)', sign_html, "未知")
            if today_points == "未知": today_points = extract_regex(r'今日积分.*?(\d+)', sign_html, "未知")
            continuous_days = extract_regex(r'erqd-continuous-days[^>]*>(\d+)', sign_html, "未知")
            if continuous_days == "未知": continuous_days = extract_regex(r'连续签到.*?(\d+)', sign_html, "未知")
            total_days = extract_regex(r'erqd-total-days[^>]*>(\d+)', sign_html, "未知")
            if total_days == "未知": total_days = extract_regex(r'总签到天数.*?(\d+)', sign_html, "未知")

            # 8.2 刷新缓存
            print("🔄 正在刷新积分缓存...")
            credit_log_url = "https://www.right.com.cn/forum/home.php?mod=spacecp&ac=credit&op=log&mobile=2"
            page.get(credit_log_url)
            time.sleep(2)

            # 8.3 获取个人资料 (双语匹配模式)
            profile_url = f"https://www.right.com.cn/forum/home.php?mod=space&uid={user_uid}&do=profile&mycenter=1&mobile=2"
            print(f"📥 正在抓取个人资料页 (UID: {user_uid})...")
            page.get(profile_url)
            
            total_points = "未知"
            contribution = "未知"
            enshan_coin = "未知"
            
            try:
                time.sleep(5)
                # 获取所有列表项
                all_lis = page.eles('tag:li')
                
                for li in all_lis:
                    clean_text = li.text.replace(" ", "").replace("\n", "").replace("\r", "")
                    if not clean_text: continue
                    
                    # === 双语匹配逻辑 ===
                    if ("积分" in clean_text and "今日" not in clean_text) or "Points" in clean_text:
                        match_cn = re.search(r'(\d+)积分', clean_text)
                        match_en = re.search(r'(\d+)Points', clean_text)
                        if match_cn: total_points = match_cn.group(1)
                        elif match_en: total_points = match_en.group(1)

                    if "贡献" in clean_text or "Contributions" in clean_text:
                        match_cn = re.search(r'(\d+)分贡献', clean_text)
                        match_en = re.search(r'(\d+)pointsContributions', clean_text)
                        if match_cn: contribution = match_cn.group(1)
                        elif match_en: contribution = match_en.group(1)

                    if "恩山币" in clean_text or "EnshanCoin" in clean_text:
                        match_cn = re.search(r'(\d+)币恩山币', clean_text)
                        match_en = re.search(r'(\d+)coinsEnshanCoin', clean_text)
                        if match_cn: enshan_coin = match_cn.group(1)
                        elif match_en: enshan_coin = match_en.group(1)
                
                print(f"📊 抓取结果: 积分={total_points}, 贡献={contribution}, 币={enshan_coin}")
                
            except Exception as e:
                print(f"❌ 数据解析异常: {e}")

            # 8.4 构建推送模版
            notify_content = (
                f"✅ 签到成功！🎊<br>"
                f"📊 积分统计如下：<br>"
                f"===========<br>"
                f"今日积分：{today_points} <br>"
                f"连续签到：{continuous_days} 天 <br>"
                f"总签到天数：{total_days} 天 <br>"
                f"总积分：{total_points} <br>"
                f"贡献分：{contribution} 分 <br>"
                f"恩山币：{enshan_coin} 币"
            )
            
            print("=== 推送内容预览 ===")
            print(notify_content.replace("<br>", "\n"))
            
            push_pushplus(push_token, notify_content)
            
            final_cookies = get_cookies_safe(page)
            save_cookie_to_config(final_cookies)
            
        else:
            print("❌ 签到失败")
            push_pushplus(push_token, f"❌ 恩山签到失败：{sign_msg}")

    except Exception as e:
        import traceback
        traceback.print_exc()
        push_pushplus(push_token, f"恩山脚本运行出错: {str(e)}")
        
    finally:
        # 9. 确保关闭浏览器并清理资源
        try:
            if page: page.quit()
        except:
            pass
        force_kill_chrome() # 再次清理，防止僵尸进程

if __name__ == "__main__":
    run_sign_in()