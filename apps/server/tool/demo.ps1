# Poziv mimo aplikacije (odbrana KT2): server odbija isto pravilo istim kodom kao aplikacija.
#
#   docker compose up -d
#   powershell -ExecutionPolicy Bypass -File apps\server\tool\demo.ps1
#
# Trka za poslednje mesto kod Jelene radi nad svežim početnim podacima; za ponavljanje:
#   docker compose down -v; docker compose up -d
param(
  [string]$Server = 'http://localhost:8080',
  [string]$Password
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
if (-not $Password) {
  $line = Get-Content (Join-Path $root '.env') | Where-Object { $_ -match '^DEMO_PASSWORD=' } | Select-Object -First 1
  $Password = $line -replace '^DEMO_PASSWORD=', ''
}
$body = Join-Path $env:TEMP 'soundconnect-demo.json'

function Call([string]$Method, [string]$Path, [string]$Json, [string]$Token) {
  $arguments = @('-s', '-X', $Method, "$Server$Path", '-H', 'Content-Type: application/json', '-w', '\n[HTTP %{http_code}]')
  if ($Token) { $arguments += @('-H', "Authorization: Bearer $Token") }
  if ($Json) {
    [IO.File]::WriteAllText($body, $Json)
    $arguments += @('--data-binary', "@$body")
  }
  & curl.exe @arguments
}

function Token([string]$Login, [string]$App = 'mobile') {
  $json = "{`"username`":`"$Login`",`"password`":`"$Password`",`"app`":`"$App`"}"
  [IO.File]::WriteAllText($body, $json)
  $answer = & curl.exe -s -X POST "$Server/api/v1/sessions" -H 'Content-Type: application/json' --data-binary "@$body"
  return ($answer | ConvertFrom-Json).token
}

function Step([string]$Title) { Write-Host "`n== $Title" -ForegroundColor Cyan }

$sava = Token 'klijent1'
$mila = Token 'klijent2'

Step 'klijent1 u backoffice: 403 wrong-app (aplikacija kaže zašto)'
Call POST '/api/v1/sessions' "{`"username`":`"klijent1`",`"password`":`"$Password`",`"app`":`"backoffice`"}"

Step 'Napomena duža od 500 znakova: 422 note-too-long, granica max 500 (isto pravilo kao u formi)'
Call POST '/api/v1/requests' "{`"providerId`":`"p-ana`",`"service`":`"mastering`",`"note`":`"$('a' * 501)`"}" $sava

Step 'Pružalac bez slobodnih mesta: 409 no-free-slots, max 3'
Call POST '/api/v1/requests' '{"providerId":"p-marko","service":"mixing","note":"Miks"}' $sava

Step 'Otkazivanje prihvaćenog zahteva r-2: 409 cancel-not-allowed'
Call POST '/api/v1/requests/r-2/cancellation' '{"from":"accepted"}' $sava

Step 'Akcija moderatora (zatvaranje r-4) kao klijent1: 403 not-allowed'
Call POST '/api/v1/requests/r-4/closure' '{"from":"delivered"}' $sava

Step 'klijent1 otkazuje tuđ zahtev r-7 (klijent2): 403 not-allowed'
Call POST '/api/v1/requests/r-7/cancellation' '{"from":"sent"}' $sava

Step 'Bez prijave: 401 sign-in-required'
Call GET '/api/v1/requests'

Step 'Trka: 6 istovremenih zahteva za poslednje mesto kod Jelene (klijent1 i klijent2) - prolazi tačno jedan'
[IO.File]::WriteAllText($body, '{"providerId":"p-jelena","service":"vocals","note":"Vokal za refren."}')
$url = "$Server/api/v1/requests"
& curl.exe -s --parallel --parallel-immediate -o NUL -o NUL -o NUL -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' `
  -H "Authorization: Bearer $sava" --data-binary "@$body" $url $url $url `
  --next -s -o NUL -o NUL -o NUL -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' `
  -H "Authorization: Bearer $mila" --data-binary "@$body" $url $url $url

Remove-Item $body -ErrorAction SilentlyContinue
