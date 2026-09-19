param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [string]$OutFile = ''
)
# 交叉编译 nbtverify（linux/arm64 静态二进制）。
# 用法:
#   powershell -ExecutionPolicy Bypass -File tools\build-aarch64.ps1 `
#       -SourceDir D:\path\to\nbtverify-src -OutFile files\usr\bin\nbtverify
$env:GOOS = 'linux'
$env:GOARCH = 'arm64'
$env:CGO_ENABLED = '0'
$env:GOPROXY = 'https://goproxy.cn,direct'

Push-Location $SourceDir
go build -trimpath -ldflags '-s -w' -o nbtverify-aarch64 .
$code = $LASTEXITCODE
Pop-Location

if ($code -ne 0) {
    Write-Error "go build failed with exit code $code"
    exit $code
}
Write-Output ("built " + (Join-Path $SourceDir 'nbtverify-aarch64'))

if ($OutFile) {
    Copy-Item (Join-Path $SourceDir 'nbtverify-aarch64') $OutFile -Force
    Write-Output ("copied to " + $OutFile)
}
