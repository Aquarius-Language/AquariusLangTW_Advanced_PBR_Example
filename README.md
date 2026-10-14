# AquariusLangTW_PBR

使用星泉（AquariusLang）重現 Michał Siejak 的 Nadrin/PBR：Cerberus 模型、原始四張 4096×4096 材質圖、HDR 街景、三盞方向光、GGX 反射、irradiance、split-sum BRDF 及最後的 HDR 色調映射。場景、輸入、矩陣、資源綁定與渲染流程皆由 `.aqua` 管理，shader 使用共用 WGSL。

先將本次更新後的 `aqua` 資料夾加入 PATH。開發機上的新編譯器位於 `C:\OfficialProjects\AquariusLangTW\dist\pbr-compiler`。

```powershell
# 本機終端機暫時加入 PATH，無須修改全域設定
$env:PATH = 'C:\OfficialProjects\AquariusLangTW\dist\pbr-compiler;' + $env:PATH
./建置.ps1
aqua run dist/PBR.wasm

# 選擇單一輸出，或另外執行兩種光照狀態的 GPU 驗證
./建置.ps1 -Target web
./建置.ps1 -Target windows -驗證
./建置.ps1 -Target android
./建置.ps1 -Target apk
```

預設 `all` 產生封裝 Wasm、Windows x64 EXE、靜態網站及新的 Android Studio / Gradle 專案。APK 建置另需 JDK 17/21、Android SDK Platform 36、Build Tools 35.0.0，並設定 `JAVA_HOME`、`ANDROID_HOME`。Android 包含 arm64-v8a 與 x86_64 原生 Vulkan 後端，最低 API 29。這四種是 AquariusLang 目前已註冊的 build targets。

網頁請透過 localhost 或 HTTPS 提供 `dist/web`，例如 `python -m http.server 8080 --directory dist/web`。不需要 PBR 的原生程式、Assimp、Python 或 CMake 即可正常建置及執行。

左鍵拖曳旋轉鏡頭、右鍵拖曳旋轉模型、滾輪縮放，F1–F3 切換方向光；1–3 也可切換光源。起始 distance=150、鏡頭／模型旋轉=0，三盞光皆關閉，和原始程式一致。投影保留原例實際使用的 GLM 數值。Windows 使用現有的 4×MSAA；瀏覽器／Android 的附件取樣數沿用平台實作，因此邊緣像素有小幅差異。

Android 與窄版網頁可直接觸控：拖曳旋轉；點畫面最下方 20% 切換鏡頭／模型；點最上方 25% 的左、中、右區切換三盞光；點中間區域左側拉遠、右側拉近。畫面保持原場景，直橫向調整只改變 aspect ratio。

`assets/original` 完整保留 supplied FBX、OBJ、PNG、HDR。`assets/baked` 是從這些資料以原例的 Assimp flags 與 OpenGL shaders 產生的跨平台資料：33,543 個三角形、原始 mip chains、1024 cube 環境、32 cube irradiance、256 BRDF LUT。切線／副切線採 half float 儲存於具名頂點紋理，保留原例的切線空間；幾何、UV、材質與光照不替換為近似模型。

編譯包只包含實際使用的烘焙資產、WGSL 與 skybox OBJ，避免攜帶重複的來源圖片。已提供的 gzip 資料在執行時以相同 core 契約載入，不會於啟動時重新烘焙。`tools/bake.cpp`、`tools/CMakeLists.txt` 與 `tools/pack-assets.py` 保留重建方式；重烘焙需原 PBR checkout、Visual Studio C++、CMake、OpenGL 4.5、NumPy 與 Pillow。

原例程式碼授權見 `PBR-LICENSE.txt`。Cerberus 由 Andrew Maximov 創作；HDR 由 Bob Groothuis 創作，源於 HDRLabs sIBL archive，原專案標示 CC-BY-NC-SA 3.0。資產來源與各自授權資訊見 `REFERENCE-README.md`；程式碼的 MIT 授權不取代資產的授權。

影像比對及平台驗證見 `驗證結果.md`。原例與重製圖保留於專案，供直接比較。
