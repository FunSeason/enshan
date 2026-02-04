# enshan_sign

2026年2月 更新的恩山论坛每日签到脚本，适用于青龙面板。

## 更新日期：2026-02-04

这是一个基于 **Python + DrissionPage** 开发的恩山无线论坛 (Right.com.cn) 自动签到脚本。

与传统的 `curl/requests` 脚本不同，本项目使用 **自动化浏览器技术**，能够完美通过 WAF 防火墙验证、自动计算 JS 指纹、支持中英文双语页面抓取，并具备 Cookie 自动续期功能，实现真正的**“一次配置，永久运行”**。

## 📂 文件树结构

Plaintext

```
Enshan-Sign-In/
├── enshan_sign.py      # 主程序代码 (核心逻辑)
├── config.json         # 用户配置文件 (需手动填入隐私数据)
└── README.md           # 说明文档
```

## ✨ 功能特性

- **🛡️ 强力过盾**：使用浏览器原生环境模拟操作，完美绕过 Cloudflare/顶象/云盾等 WAF 防火墙拦截。
  
- **🍪 Cookie 自愈**：自动检测 Cookie 有效性，若过期自动触发浏览器验证获取新 Cookie 并回写至配置文件，无需人工干预。
  
- **🌍 双语适配**：智能识别页面语言，兼容论坛自带翻译插件导致的英文/乱码页面，准确抓取积分数据。
  
- **♻️ 进程自愈**：内置僵尸进程清理机制，防止在 Docker/青龙面板中因浏览器残留导致的内存泄漏或启动失败。
  
- **⏰ 随机延迟**：启动前随机等待 0-900 秒，模拟真实用户行为，降低风控风险。
  
- **📲 消息推送**：支持 PushPlus 微信推送签到结果及详细积分统计。
  

## 🛠️ 环境依赖 (青龙面板必看)

本脚本需要运行完整的 Chromium 浏览器内核，因此对环境有特殊要求。

### 1. Python 依赖

在青龙面板的 **“依赖管理” -> “Python3”** 中添加：

Plaintext

```
DrissionPage
requests
```

![](https://github.com/FunSeason/enshan/blob/main/image/capture_01.png)

### 2. Linux 系统依赖 (核心)

由于青龙面板通常是轻量级容器，**默认没有安装浏览器**。

请在青龙面板的 **“依赖管理” -> “Linux”** 中添加以下包（Alpine Linux）：

Plaintext

```
chromium
chromium-chromedriver
```

> **注意**：安装 Chromium 可能需要几分钟时间，请耐心等待安装日志显示“成功”。

![](https://github.com/FunSeason/enshan/blob/main/image/capture_02.png)

---

## ⚙️ 配置文件说明

请下载或新建 `config.json` 文件，并填入您的个人信息：

JSON

```
{
  "PUSHPLUS_TOKEN": "您的PushPlus_Token",
  "USER_UID": "您的恩山论坛UID",
  "cookie": "您的初始Cookie字符串"
}
```

![](https://github.com/FunSeason/enshan/blob/main/image/capture_03.png)

**参数获取方式：**

1. **PUSHPLUS_TOKEN**: 前往 [PushPlus官网](https://www.pushplus.plus/) 获取。若不使用推送，留空即可。若使用其他推送方式，请自行修改相关推送代码或者可将`enshan_sign.py` 和`config.json`这两个文件喂给豆包、deepseek等，让AI大模型来修改为需要的推送方式的相关代码即可。
  
2. **USER_UID**: 登录恩山论坛 -> 点击右上角头像 -> 地址栏 `uid=` 后面的数字即为 UID (例如 `1000005`)。
  
3. **cookie**:
  
  - 电脑浏览器打开恩山论坛并登录。
    
  - 按 `F12` 打开开发者工具 -> 点击 `Network` (网络)。
    
  - 刷新页面，点击第一个请求（通常是 `forum.php`）。
    
  - 在右侧 `Headers` (标头) 中找到 `Cookie:`，复制其后的所有字符串。
    

---

## 🚀 运行方式

### 方式一：青龙面板 (推荐)

1. **上传文件**：将 `enshan_sign.py` 和 `config.json` 上传至青龙面板的脚本目录（建议新建一个文件夹，如 `NewEnshan`）。
  
2. **配置依赖**：确保按照上文完成了 Python 和 Linux 依赖的安装。
  
3. **设置定时任务**：
  
  - **建议频率**：每天一次（脚本非常稳健，不需要高频运行）。
    
  - **Cron 表达式**：`0 9 * * *` (每天上午 9 点运行)。
    
4. **运行测试**：点击“运行”按钮，查看日志。首次运行成功后，会显示积分统计并推送消息。
  
![](https://github.com/FunSeason/enshan/blob/main/image/capture_04.png)


### 方式二：本地运行 (Windows/Mac/Linux)

1. 安装 Python 3.8+。
  
2. 安装库：`pip install DrissionPage requests`。
  
3. 安装 Chrome 或 Edge 浏览器。
  
4. 修改代码中的浏览器路径配置（如果脚本找不到浏览器的话）。
  
5. 运行：`python enshan_sign.py`。
  

---

## 📊 优缺点分析

| **维度** | **说明** |
| --- | --- |
| **稳定性** | ⭐⭐⭐⭐⭐ <br> 极高。通过调用真实浏览器内核，从根本上解决了 WAF 拦截和指纹识别问题。 |
| **维护成本** | ⭐⭐⭐⭐⭐ <br> 极低。Cookie 过期会自动续期，基本不需要人工维护。 |
| **资源占用** | ⭐⭐ <br> 较高。运行浏览器比简单的 `curl` 请求占用更多内存和 CPU（建议在 1G 内存以上的环境运行）。 |
| **运行速度** | ⭐⭐⭐ <br> 较慢。包含随机延迟和浏览器加载渲染时间，单次运行约需 1-2 分钟。 |

---

## 📝 常见问题 (FAQ)

**Q: 运行日志提示 `The browser connection fails`？**

A: 这是因为浏览器启动失败。

1. 请检查“依赖管理”->“Linux”中是否安装了 `chromium`。
  
2. 脚本已内置清理功能，如果是偶发性失败，下一次定时任务通常会自动恢复。
  

**Q: 为什么日志里显示积分数据是“未知”？**

A: 请检查日志中是否有 `PushPlus 通知已发送`。如果脚本流程走完了但没抓到数据，可能是网络极差导致页面加载超时。脚本已针对中英文页面做了适配，通常不会出现此问题。

**Q: 需要每天运行很多次来保活 Cookie 吗？**

A: **不需要**。本脚本具备“过盾”能力，即使 Cookie 彻底失效，脚本也能像真人一样重新登录验证。建议每天运行 1 次即可。

---

## ⚠️ 免责声明

- 本脚本仅供学习交流使用，请勿用于商业用途。
  
- 使用本脚本产生的任何后果（如账号被封禁等）由使用者自行承担。
  
- 请遵守恩山无线论坛的相关规定，合理使用自动化工具。








# 以下内容已失效，可忽略不看。
# 以下内容已失效，可忽略不看。
# 以下内容已失效，可忽略不看。

## 更新日期：2026-02-03

最近一直在忙其他事情，完全没有留意到由于论坛护盾升级，导致脚本失效；好像有热心网友1月份就发邮件？（不知道是不是站内的，忘了）提醒，但我是2月才看到，抱歉！

这个shell脚本失效了。但
💡 **核心矛盾**是 curl (Shell脚本) 的技术天花板，而不是脚本写得不对。

恩山的防火墙（顶象/云盾）机制：
Cookie 到期后，服务器会返回一段 <script>...</script> 代码，浏览器会自动运行它，算出新的 Token，然后自动刷新拿到新 Cookie。

而Shell 脚本的能力：
只能看懂文本，看不懂也跑不了那段 <script> 代码。

结果：一旦到了硬性过期时间，脚本就必死无疑，无法自救。

🛠️ **现在的选择**

既然纯 Shell 脚本无法突破这个限制，有以下两种选择：

### 方案 A：继续使用当前脚本（接受半自动）
如果不想折腾复杂的环境（如 Python/Docker），依然想用这个 Shell 脚本：

接受现状：这个脚本无法实现“永久全自动”。

操作频率：恩山的防火墙 Cookie 有效期大约是 6-12 小时（或者是每日固定重置）。

维护方式：需要每天（或每当收到失败推送时）手动提取一次 Cookie 填入 config.json。

优点：脚本轻量，随处可跑。

缺点：人肉运维，非常烦。


### 方案 B：彻底解决（使用 Python/浏览器模拟）
如果您有能力在设备上运行 Docker 或者 Python，或者在青龙面板中安装需要的python、linux依赖，就可以使用更高级的方案。 

只有使用 Selenium、Puppeteer 或 DrissionPage 这类能“模拟真实浏览器”的工具，才能在 Cookie 过期时自动运行 JS 代码，实现真正的“永久自动续期”。

现在已经有一个基于 Python + DrissionPage 的解决方案了，为了验证可用性，要等明天看能否正常使用。

若无其他意外，将于2026年02月04日更新这个解决方案。

## 更新日期：2025-12-16

增加了定时执行随机摇摆函数。（即到定时后，生成0-900秒的随机数（15分钟=900秒），倒数结束再执行）

## 使用方法（以青龙面板以及pushplus推送为例）

**<mark><u>自行获取恩山论坛自己账号的UID、cookies以及通知推送方式的token。</u></mark>**

1、打开青龙面板的脚本管理

2、复制/导入本仓下的config.json文件到自己青龙面板的脚本管理

3、修改config.json中为自己的UID、cookies以及推送token

![](https://github.com/FunSeason/enshan/blob/main/image/01.png)

4、复制/导入本仓下的enshan.sh文件到自己青龙面板的脚本管理

                *<mark>注意config.json和enshan.sh放在同一目录下。</mark>*

5、自定义定时任务，时间到了就会自动执行。

![](https://github.com/FunSeason/enshan/blob/main/image/02.png)

# 推送结果示例如下：

![](https://github.com/FunSeason/enshan/blob/main/image/03.png)
