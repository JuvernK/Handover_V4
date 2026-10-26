# Jev 整合補強版 2.0.0

這是你提供的 Claude Code + Jev 工具的修改版，包含完整原始碼、離線測試和本機安裝器。它保留 `.claude/jev/state` 的 `on`／`off` 介面，修正模型分流、敏感資料傳送、技能建議與狀態顯示。

**Jev 負責提供選擇建議，Claude 主對話負責理解任務、決定是否委派，以及檢查成果。** 本工具不會直接切換主模型，也不會自行建立子代理。分流紀錄中的 `selected_model` 是建議使用的模型，不代表已經執行。

## 安裝

需要 Python 3.9 以上、Git，以及你原本使用的 Claude Code。只用 Python 標準函式庫，不需要 `pip install`。此套件以 macOS／Linux 為目標；本次測試在 Linux + Python 3.12 執行。

1. 解壓縮 `jev-hardened-v2.zip`。
2. 關閉正在使用同一專案的 Claude Code 工作階段，避免安裝途中舊 hook 同時執行。
3. 在終端機進入解壓縮後的 `jev-hardened-v2` 資料夾。
4. 將以下路徑換成你的專案根目錄，執行安裝。專案根目錄是包含 `.claude` 的那一層，不是 `.claude/jev`。

```bash
python3 install.py --project "/Users/你的帳號/你的專案"
```

如果想先看安裝計畫，可先執行：

```bash
python3 install.py --project "/Users/你的帳號/你的專案" --dry-run
```

`--dry-run` 只檢查並顯示計畫，不寫檔，也不呼叫 Jev。安裝器會在本機執行 `claude --version`，以判斷能註冊哪些 hook。

安裝器會：

- 備份即將變動的檔案，再安裝新程式。備份預設位於專案之外的 `~/.claude/jev-backups/`，實際位置會印在終端機。
- 保留原本的 `state` 開關值、API key、權限設定、其他 mod／hook，以及你的技能目錄和有效的自訂設定。
- 更新本工具可辨識的 hook，避免重複註冊同一個直接呼叫。
- 保留第三方 `statusLine`。若原本就是本工具的狀態列，則更新；若沒有設定，則加入本工具的狀態列。
- 私下備份含原始 prompt 的舊 `last-decision.json`，再以不含原文的初始紀錄取代。新版壓縮包不包含你的舊 prompt。
- 遇到無效設定或符號連結目標時停止。若寫入途中失敗，會嘗試還原已變動檔案，並提供備份位置。

安裝完成後重新開啟該專案的 Claude Code。若是第一次安裝，開關預設為 `off`；更新既有安裝則保留原值。此處提供的是可安裝套件，並未遠端安裝到你的電腦。

若既有 hook 把 router 與其他命令串在一起，或帶有工具不認得的參數，安裝器會原樣保留並提示可能重複呼叫。此時應檢查那個 wrapper，避免同一回合送出兩次 Jev 請求；工具不會為去除重複而刪掉你的其他 mod 命令。

### 關於你原本的 mod

只要 mod 仍讀寫 `.claude/jev/state` 的純文字 `on`／`off`，這個介面就能沿用。套件也保留 `toggle.sh on`、`off`、`status`、`last`。

本次沒有取得 mod 本身的原始碼、你實際使用的 hook 設定或 slash command 定義，因此沒有把 mod 判定為已完成安全稽核，也無法保證它是否依賴其他舊檔案格式。安裝器不會修改那些未提供的 mod 或 slash command。

## 每天怎麼用

### 1. 用原本的開關，或終端機命令

以下命令在你的專案根目錄執行：

```bash
bash .claude/jev/toggle.sh on
bash .claude/jev/toggle.sh status
bash .claude/jev/toggle.sh last
bash .claude/jev/toggle.sh off
```

**這是專案共用開關，現在同時控制 router 和 checker 的 Jev 請求。** 同專案的多個 Claude 工作階段共用它。關閉後仍可做本機 diff 預覽；已經送出的網路請求無法收回。

如果原本的 `/jev on` 等指令只是呼叫這支 `toggle.sh`，可以繼續使用。`last` 顯示整個專案最近一次分流的中繼資料；每個工作階段自己的狀態列則讀取自己的紀錄。

### 2. 把適合委派的任務講清楚

例如：「把 `src/labels.py` 裡三個顯示名稱改成新名稱，保留對外 API，確認既有測試仍能通過。」這種範圍清楚、可以檢查的本機工作，比「照剛才的改」適合交給新子代理。

Jev 一次評估工作需求、前文依賴、模型、技能和風險。若建議較小模型，Claude 還是要根據完整前文確認可行，再把目標、範圍、驗收條件與既有決定交給子代理。

你明確指定模型、已給出的授權和原本的權限設定，都優先於 Jev 建議。遇到「同意，幫我改」這種延續上一輪的訊息，主對話應接著完成已授權的工作，不會因 `needs_work=no` 被要求停止。

### 3. 改完程式，先預覽要檢查的差異

```bash
python3 .claude/jev/check.py
```

這只顯示本機預覽，不呼叫 API。預設包含已追蹤檔案相對於 `HEAD` 的暫存與未暫存修改，排除敏感檔案。新建但未追蹤的檔案必須明確加入：

```bash
python3 .claude/jev/check.py --include-untracked
```

可以限定檔案、資料夾或提交，路徑一律放在 `--` 後：

```bash
python3 .claude/jev/check.py -- src/labels.py
python3 .claude/jev/check.py HEAD~1 HEAD -- src/
python3 .claude/jev/check.py main...HEAD
```

沒有任何修改時，不會自行改成檢查上一個提交。要檢查上一個提交，請明確使用 `HEAD~1 HEAD`。初始、尚未建立提交的 Git 專案也能預覽其暫存與未暫存修改。

### 4. 要送出時，加上 `--send`

```bash
python3 .claude/jev/check.py --send -- src/labels.py
```

這會重新收集當下的差異，因此預覽後又修改檔案時，應重新預覽。送出必須同時滿足 `state=on`、有本機 API key、內容通過本機檢查且大小在限制內。

checker 仍一次問四題：測試是否變弱、錯誤是否被不當忽略、函式是否有名稱未表達的副作用，以及註解是否已和程式矛盾。每題的數值越高，代表 Jev 越傾向認為有該問題。

**低分不代表測試通過，也不代表程式安全。** `status: completed` 只表示四個答案完整且格式有效。仍要執行專案原本的測試及必要的人工審查。

如果你原本的 `/jev-check` 只呼叫 `check.py`，現在會變成本機預覽。只有當該 slash command 會轉交參數時，`/jev-check --send` 才有同樣效果；否則請使用上面的終端機命令。未提供 slash command 定義，本套件不擅自替換它。

## 如何對應你的四條守則

| 守則 | 新版的具體處理 |
| --- | --- |
| 獨立問題與假設問題一次問 | router 五個問題放在同一個 API 請求，互不引用其他答案。checker 四題也一次送出。若技能目錄只有 `none`，在本機直接使用它，省去沒有選擇意義的 API 題目。 |
| 建議選項保留「以上皆非」 | 模型加入 `defer_to_main`，技能保留 `none`，風險加入 `unknown`。有明確二元意義的工作／前文題目不硬加第三個選項。 |
| 正確解讀回傳數字 | 驗證答案型別、選項白名單、完整機率分布、範圍、總和、最高分選項及 confidence 的一致性。拒絕缺值、NaN、Infinity 和未知模型選項。confidence 只表達選項分布，不能當成答對率。 |
| 門檻依答錯後果設定 | 低風險且不依賴前文的降級使用最高分選項，不再套用固定 `0.6`。高風險／風險不明時不為省錢而降級；升級不受原本的降級門檻阻擋。高分不構成操作授權。 |

風險分類本身也可能判錯。新版不把「Jev 說低風險」當作安全證明；分流提示要求主對話依完整任務確認。對高後果操作，本版保留主對話的判斷與既有權限控制，沒有自創一個「超過 90% 就可自動部署／付款」的規則。

## 分流優先順序

| 條件 | 建議行為 |
| --- | --- |
| 回應格式無效、網路失敗、缺 key、開關關閉 | 不注入分流建議，主對話照原本任務繼續；可寫入不含原文的原因代碼。 |
| 簡短延續、授權或工作回報 | 主對話根據前文解讀，不自動載入技能。 |
| `defer_to_main` | 回主對話解讀或補足必要資訊。 |
| 無法確認主模型 | 不假設為 Opus，不根據未知基準宣稱降級省錢。 |
| 依賴前文 | 先在主對話規劃。必要時由主對話整理完整交接資訊後再委派。 |
| 建議與主模型同級 | 建議直接在主對話處理。 |
| 建議更強模型，且前文條件已滿足 | 可以建議升級，不套降級的信心門檻。 |
| 建議較便宜模型，但風險高／不明 | 留在主對話，不以成本為由降低能力。 |
| 建議較便宜模型，且工作獨立、低風險 | 建議委派，主對話仍需確認範圍並檢查結果。 |

這只處理每次 submitted turn 的建議，不是攔截之後每個 `Agent` 呼叫的強制模型路由器。Claude Code 的排程回合或工作回報也可能觸發 `UserPromptSubmit`；目前沒有可依賴的官方來源旗標讓本工具完全排除它們。

## 資料會送到哪裡

唯一寫在程式中的外部 API 目標是：

`https://api.typesafe.ai/v1/systemone`

router 送出目前這一輪經檢查的 prompt、題目及 `skills.json` 中的技能名稱／說明；不主動讀取完整聊天紀錄或專案檔案。checker 只在明確使用 `--send` 時送出選定的差異和四個題目。

`TYPESAFE_API_KEY` 先從環境變數讀取，沒有時從 macOS Keychain 的 `typesafe-jev-api-key` 項目讀取（`security find-generic-password -s typesafe-jev-api-key -w`）。不再讀取 `.claude/settings.local.json` 的 `env`：那裡的值會注入 Claude Code 啟動的每個子程序，容易被印進對話紀錄。存入或更換 key 時，在自己的 Terminal 執行 `security add-generic-password -a "$USER" -s typesafe-jev-api-key -U -w`，依提示貼上兩次。不會把 key 印出、放入分流紀錄或打包進此套件。HTTPS 重新導向會被拒絕，不會把 Authorization 標頭跟著導向其他網址。API 回應大小有上限，錯誤訊息不輸出伺服器原始 body，也不自動重試。

### 敏感資料的預設行為

`sensitive_handling` 預設為 `skip`。偵測到已知憑證、短密碼、多字密碼、私鑰、email 或有欄位名稱的私人識別資料時，跳過 Jev 請求。這也會檢查技能描述和其他送出欄位。

checker 會排除 `.env`、私鑰、憑證檔、Claude 設定和本工具的執行紀錄，**即使它們已被 Git 追蹤**。`config.json` 的 `exclude_globs` 可追加專案特有的敏感路徑。核心排除規則不因自訂設定而取消。

若你明確接受傳送遮蔽後的資料，可把設定改成：

```json
"sensitive_handling": "redact"
```

這會送出遮蔽後的文字，且 router 不會根據被遮蔽的 prompt 自動載入技能。**字串比對無法辨認所有機密、個資或商業秘密**，無法保證完整去識別化。遇到客戶資料、未公開程式或公司禁止外傳的內容，應關閉 Jev；不應把「沒有命中規則」解讀為已經通過資料外傳審批。

### 本機紀錄

`last-decision.json` 只保存時間、版本、選項、機率、原因、模型來源、token 用量與字數等中繼資料，不保存 prompt、diff、API key 或原始 API body。每個工作階段的紀錄放在 `.runtime/`，檔名使用 session ID 的雜湊。

新建的私人資料夾使用 `0700`，檔案使用 `0600`，以暫存檔加原子替換方式更新，避免讀到寫了一半的 JSON。runtime 中過期紀錄會在分流記錄時有限量清理，預設保留 7 天；這不是系統排程，也不會掃描其他專案。全域 `last-decision.json` 保留最近一筆，安裝備份則保留到你自行清理。

備份可能包含你原有的 API key 和舊 prompt，因此安裝器將它放在專案外且限制權限，不要把整份備份上傳。這不會刪除 Claude Code 原有的 transcript，也不會替已提交的舊機密改寫 Git 歷史。

## 技能目錄與自動載入

保留你原本的 `skills.json`，但目錄只描述候選技能，不負責安裝或證明那些技能值得信任。請刪除你沒有安裝、不使用或不想送給 Jev 判斷的項目，保留 `none`。

`auto_load_skills` 預設為空陣列，因此技能只會被建議。若你已閱讀某個技能，且想讓符合條件的任務自動載入，可在 `config.json` 明確加入其完整名稱，例如：

```json
"auto_load_skills": ["code-review"]
```

設定、權限、排程、瀏覽器操作、外部資料寫入等已知敏感類型，即使在這個清單中，也不會單憑 router 自動載入。自訂別名無法完全靠名稱辨識風險，所以只應加入你確實審核過的技能。任何技能的載入都不新增工具權限，也不授權發布、發訊息或其他副作用。

## 主模型與狀態列

主模型來源依序是本輪 payload、可用且未過期的同 session 追蹤紀錄，以及你明確設定的 `main_tier`。沒有資料就顯示或記錄 `unknown`，不默認為 Opus。

安裝器只在偵測到 Claude Code **2.1.251 以上**時註冊 `PostModelSwitch`。較舊或無法辨識的版本，可透過本工具自己的 status line 更新模型。若還保留第三方 status line，就不信任可能失準的 SessionStart 快取。

這時可選擇在 `config.json` 明確設定：

```json
"main_tier": "sonnet"
```

手動值必須與你當時的主模型一致，使用 `/model` 切換後也要更新；如果無法維護，保留 `null` 讓工具採取保守退路。更新 Claude Code 後重新執行安裝器，才會重新判斷可用 hook。

自動追蹤仍有時序與版本限制。官方 `PostModelSwitch` 追蹤的是 session 模型改變，不涵蓋只代替單一回合的 fallback。

| 顯示 | 代表什麼 |
| --- | --- |
| `Jev: ON` | 開關開啟，不表示 API key 有效或最近請求成功。 |
| `route: suggested haiku` | Jev 建議 Haiku，尚不能證明 Claude 已委派。 |
| `route: skipped (...)`／`error (...)` | 該次分流跳過或失敗，括號內為原因。 |
| `recent worker start: ...` | Claude 的 `resolvedModel` 回報該子代理的起始模型。 |
| `recent worker launch: ...` | Claude 回報子代理轉入背景時的模型。 |

最近的 worker 紀錄與目前的分流建議分開顯示，不會把非同步的舊 worker 硬配到最新任務。`resolvedModel` 不一定是最後或全程使用的模型；本工具也沒有用單一回應的 token 數估算整個 worker 的費用。

## 成本怎麼看

本版修正了造成錯誤分流與重做的幾個原因，但不保證每項任務都省錢。你仍有主模型做規劃、交接與驗收的成本，Jev 每次請求也有輸入 token 成本。平行問多題有助於縮短等待，額外的題目和技能描述仍會增加 token。

最有用的日常調整是：只在可能委派的工作時開啟、讓任務描述可獨立理解、縮減不用的技能選項、把 diff 限在一個改動主題，並比較類似任務的完成品質、重試次數和實際用量。聊天、連續追問同一脈絡或敏感工作可以關閉。

`jev_model` 固定為 `jev-1.13.0`，避免 `jev-latest` 別名更新後無聲改變行為。如果你改模型版本、題目或風險政策，應重新用自己的已知任務觀察品質。本套件的測試驗證程式分支和安全邊界，不是 Jev 模型的正確率評測。

## 設定與退出碼

主要設定集中於 `.claude/jev/config.json`，無需修改程式碼。

| 設定 | 預設 | 用途 |
| --- | --- | --- |
| `main_tier` | `null` | 只在必要時明確指定主模型級別。 |
| `sensitive_handling` | `skip` | 偵測到敏感內容時跳過請求。 |
| `auto_load_skills` | `[]` | 明確審核過的自動載入名單。 |
| `max_prompt_chars` | `20000` | prompt 上限，超過則跳過。 |
| `max_diff_chars` | `60000` | diff 上限，超過則拒絕，不截斷。 |
| `request_timeout_seconds` | `12` | API 網路操作 timeout。 |
| `git_timeout_seconds` | `15` | 每次 Git 呼叫的 timeout。 |
| `model_tracking_max_age_seconds` | `86400` | 模型快取最長可用時間。 |
| `log_retention_days` | `7` | runtime 過期紀錄的清理期限。 |

checker 的退出碼：

| 退出碼 | 意義 |
| --- | --- |
| `0` | 本機預覽完成，或四個 Jev 答案完整。不是測試通過證明。 |
| `2` | 錯誤，或明確要求送出但被跳過。 |
| `3` | 只有你使用 `--send --fail-on-problem`，且任一問題機率大於 `0.7` 時才回傳。 |

`0.3`／`0.7` 預設只用來標記「較不像問題／不確定／較像問題」。`--fail-on-problem` 是可選的 CI 行為，不是對所有任務強制設置門檻；採用前應用你自己的案例校準。

## 測試與檔案

在解壓縮目錄，或安裝後的 `.claude/jev` 目錄中執行：

```bash
python3 -m unittest discover -s tests -v
```

測試全部離線，以模擬 API 與暫存 Git 專案驗證，不需要 API key、不產生 Jev 費用。涵蓋模型升降級、前文保留、資料遮蔽、開關、回應驗證、Git 範圍，以及安裝器的備份、還原與設定保留。詳見 `VALIDATION.md`。

| 檔案 | 工作 |
| --- | --- |
| `route.py` | 建立一次分流請求、套用政策、注入建議。 |
| `check.py` | 本機差異預覽及明確送出的四題檢查。 |
| `jev_common.py` | API、驗證、遮蔽、設定、模型追蹤及私人紀錄。 |
| `session.py`／`observe.py` | 分別記錄主模型變動與 Claude 回報的 worker 模型。 |
| `statusline.py`／`toggle.sh` | 顯示狀態及維持既有開關介面。 |
| `install.py` | 本機更新、設定合併、私人備份和失敗還原。 |
| `config.json`／`skills.json` | 你的可調整設定和候選技能目錄。 |
| `tests/` | 可重跑的離線測試。 |

若先暫停這個整合，只需將開關設為 `off`。它會停止新的 Jev 請求，本機模型中繼資料仍可能被生命週期 hook 更新。若需回到舊版，先關閉 Claude Code，依安裝器印出的備份位置還原對應檔案；備份中的 `manifest.json` 列出哪些是原本存在的檔案。不要把舊備份覆蓋到後來另有改動的設定而未先比較。

## 官方參考

下列為此次修改時核對的官方文件，查閱日期：2026-10-21。

- [TypeSafe System One API](https://docs.typesafe.ai/api/system-one)
- [Choice：答案分布、一次問多題與 none 選項](https://docs.typesafe.ai/primitives/choice)
- [Confidence：公式及依風險調整處理方式](https://docs.typesafe.ai/confidence)
- [TypeSafe 模型版本](https://docs.typesafe.ai/models)
- [Jev 1.13 的已知限制](https://docs.typesafe.ai/model-jaggedness/jev-1.13)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code status line](https://code.claude.com/docs/en/statusline)

這是針對你提供的整合程式所做的補強，不是 TypeSafe 或 Anthropic 官方發布或認證的套件。
