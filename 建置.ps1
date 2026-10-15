#requires -Version 5.1
param(
    [ValidateSet('all','wasm','web','windows','android','apk')][string]$Target='all',
    [switch]$驗證,
    [string]$Compiler
)
$ErrorActionPreference='Stop'
$編譯器=if($Compiler){(Resolve-Path -LiteralPath $Compiler).Path}else{
    # 同層語言專案有已建置的編譯器時，使用包含最新主機修正的版本。
    $本機編譯器=Join-Path $PSScriptRoot '../AquariusLangTW/AquariusCli/bin/Release/net8.0/aqua.exe'
    if(Test-Path -LiteralPath $本機編譯器){(Resolve-Path -LiteralPath $本機編譯器).Path}
    else{(Get-Command aqua -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source}
}
function 編譯([string[]]$參數) {
    & $編譯器 @參數
    if($LASTEXITCODE -ne 0){throw "星泉建置失敗（結束碼 $LASTEXITCODE）。"}
}
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path dist | Out-Null
    Write-Host "編譯器：$編譯器"
    # 原始 FBX / HDR / PNG 保留於專案；執行包只攜帶實際使用的烘焙資源。
    $參數=@('build','main.aqua','場景.aqua','驗證.aqua','--root','.','--entry','main.aqua','--assets','assets/original/meshes/skybox.obj')
    foreach($檔案 in Get-ChildItem -LiteralPath assets/baked -File | Where-Object {$_.Extension -in @('.gz','.aqmesh')}){$參數+=@('--assets',('assets/baked/'+$檔案.Name))}
    foreach($檔案 in Get-ChildItem -LiteralPath assets -Filter '*.wgsl' -File){$參數+=@('--assets',('assets/'+$檔案.Name))}
    $參數+=@('-o','dist/PBR.wasm')
    編譯 $參數
    if($驗證){編譯 @('run','dist/PBR.wasm','--entry','驗證.aqua')}
    if($Target -in @('all','web')){
        編譯 @('build','dist/PBR.wasm','--target','web','-o','dist/web')
        $首頁=Join-Path $PSScriptRoot 'dist/web/index.html'
        $內容=[IO.File]::ReadAllText($首頁).Replace('lang="en"','lang="zh-Hant"').Replace('<title>Aquarius WebAssembly</title>','<title>Physically Based Rendering · 星泉</title>')
        [IO.File]::WriteAllText($首頁,$內容,[Text.UTF8Encoding]::new($false))
    }
    if($Target -in @('all','windows')){編譯 @('build','dist/PBR.wasm','--target','windows','-o','dist/PBR.exe')}
    if($Target -in @('all','android')){
        $輸出='dist/android-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
        編譯 @('build','dist/PBR.wasm','--target','android','--application-id','tw.aquariuslang.pbr','--app-name','星泉 PBR','-o',$輸出)
        Write-Host "Android Studio 專案：$輸出"
    }
    if($Target -eq 'apk'){編譯 @('build','dist/PBR.wasm','--target','android','--application-id','tw.aquariuslang.pbr','--app-name','星泉 PBR','-o','dist/PBR.apk')}
    Write-Host "完成：$Target。可執行 aqua run dist/PBR.wasm，或以 localhost 提供 dist/web。"
} finally {Pop-Location}
