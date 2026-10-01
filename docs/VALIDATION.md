# Godot 版驗證紀錄

日期：2026-10-01，Asia/Taipei。引擎：Godot 4.7.2 stable，標準版。原生圖形檢查環境：macOS / Apple M4 / OpenGL Compatibility；瀏覽器：本機 Google Chrome / WebGL 2。

## 訓練模型

`tests/test_simulator.gd`：**64 個案例、1,200 項斷言，0 失敗**。

- A／G 的逐項順序、九類知識、八方向真實控制輸入、繞機及口誦結束。
- B 五段有效停懸與順時針旋轉；錯誤高度及錯向旋轉反例。
- C 左圓→右圓、D 八段停懸與三級後退距離。
- E 三級、左右來風、五邊爬升／下降，拒絕純垂直或水平飛行完成斜航點。
- F 原處懸停、最近內圈、口令確認、漂移與逾時反例，以及自動監評口令。
- 暫停凍結、一般偏差不設累計中止、短暫修正保留停懸時間、偏差分類不重複計入總時間。
- 旋轉後起落架壓線、碰撞、安全空域、提前落地與墜落反例。
- 兩種練習模式 B–F 的完整控制輸入流程；三級姿態模式 B–F；三級右來風 E；兩種模式完整 A–G 與空中銜接。

正向完整流程以控制器產生前後、平移、升降及轉向輸入推進，不直接修改飛行座標來假裝完成。隔離反例會明確注入錯誤狀態，驗證安全判定。

## 原生介面

`tests/test_ui.gd`：無畫面模式 **28 項斷言，0 失敗**；圖形模式 **35 項斷言，0 失敗**，另驗證 PNG 截圖與 JSON 文件。涵蓋真實 `Input.parse_input_event` 鍵盤輸入、八方向檢查、口令啟動、Space 馬達、W 爬升、P 暫停、失焦、關閉對話框仍暫停、置中保護、音效樣本、全部靜音、獨立練習限制與虛擬搖桿。

螢幕截圖已人工檢查繁體中文字型、場地光照、儀表、航線、科目與視窗縮小後的版面：

- `screenshots/01-workstation.png`：完整工作站。
- `screenshots/02-hover-training.png`：實際輸入爬升後的 B 科。
- `screenshots/03-five-leg-course.png`：E 科斜航線。
- `screenshots/04-compact-window.png`：1080×720 視窗。
- `screenshots/05-training-records.png`：A 科完成後的結果。

## 匯出與執行

四個平台匯出與壓縮完成；各套件附引擎／字型授權，另提供 SHA256SUMS。

| 目標 | 已驗證 |
| --- | --- |
| macOS universal | 官方模板匯出、解壓縮、獨立 app 啟動、`codesign --verify --deep --strict`。 |
| Windows x64 | 官方模板跨平台匯出、產生含 PCK 的 EXE 及 ZIP。 |
| Linux x64 | 官方模板跨平台匯出、產生含 PCK 的 ELF 及 ZIP。 |
| Web single-thread | Chrome 實際載入 3D、選科、Enter／Space／P、結果對話框、JSON 下載。 |

Web 實測找出的合成音訊 sample 播放警告已改為 stream 播放。重載最新匯出後沒有新的 warning／error；下載的 JSON 已從磁碟解析，驗證應用名稱、schema、練習成績用途與模擬容差。

本機 JSON、啟動器語法、Python 匯出／伺服器工具與模板路徑還原亦經檢查。來源專案的 Git 工作目錄維持乾淨。

## 驗證界線

尚未在實體 Windows／Linux 電腦、實體遊戲手把或手機多點觸控上測試；未實際聆聽各作業系統中文語音。虛擬搖桿與鍵盤測試、音訊樣本生成，不等同上述硬體驗收。

macOS 發行套件使用 ad-hoc 簽署，沒有 Apple 公證。訓練流程與模擬容差沿用使用者指定的原專案；本次沒有重新核對官方 PDF，也沒有實機飛行或正式鑑評驗證。
