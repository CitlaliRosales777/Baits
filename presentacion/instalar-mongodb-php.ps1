param([string]$Php = 'C:\xampp\php\php.exe')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Php -PathType Leaf)) { throw "No se encontró php.exe en $Php." }
$Php = (Resolve-Path -LiteralPath $Php).Path

function Read-Php {
    param([string[]]$Arguments)
    # PHP puede avisar de una DLL ausente al leer el archivo de configuración actual.
    $ErrorActionPreference = 'Continue'
    & $Php @Arguments 2>$null
}

if ((Read-Php @('-m')) -contains 'mongodb') {
    Write-Host 'La extensión mongodb ya está activa en este PHP.'
    return
}

$info = (Read-Php @('-n', '-i')) -join "`n"
if ($info -notmatch '(?m)^PHP Version => (8\.[1-5])\.') { throw 'El controlador previsto requiere PHP 8.1 a 8.5. Revisa la versión de XAMPP.' }
$version = $Matches[1]
if ($info -notmatch '(?m)^PHP Extension Build => API\d+,(NTS|TS),(VS\d+)') { throw 'No se pudo identificar cómo se compiló PHP.' }
$thread = $Matches[1].ToLowerInvariant()
$compiler = $Matches[2].ToLowerInvariant()
if ($info -notmatch '(?m)^Architecture => (x64|x86)\s*$') { throw 'El controlador para Windows requiere PHP de arquitectura x64 o x86.' }
$architecture = $Matches[1]

$config = @(Read-Php @('-d', 'display_errors=stderr', '-r', "echo php_ini_loaded_file(), PHP_EOL, ini_get('extension_dir');"))
if ($config.Count -lt 2 -or -not (Test-Path -LiteralPath $config[0].Trim() -PathType Leaf)) {
    throw 'PHP no cargó un php.ini. Ejecuta php --ini para revisar la configuración de XAMPP.'
}
$ini = $config[0].Trim()
$extensionDir = $config[1].Trim()
if (-not [IO.Path]::IsPathRooted($extensionDir)) { $extensionDir = Join-Path (Split-Path -Parent $Php) $extensionDir }
if (-not (Test-Path -LiteralPath $extensionDir -PathType Container)) { throw "No se encontró la carpeta de extensiones $extensionDir." }
$dll = Join-Path $extensionDir 'php_mongodb.dll'

# Carga la DLL sin leer php.ini para comprobar la compatibilidad antes de cambiar la configuración.
function Test-MongoDll {
    param([string]$Path)
    (Read-Php @('-n','-d',"extension=$Path",'-m')) -contains 'mongodb'
}

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$iniBackup = "$ini.moodsitto-$stamp.bak"
$dllBackup = "$dll.moodsitto-$stamp.bak"
$downloadDir = Join-Path $env:TEMP "moodsitto-php-$stamp"
$zip = $null
$candidate = $null
$dllChanged = $false
$iniChanged = $false
try {
    if (-not (Test-Path -LiteralPath $dll) -or -not (Test-MongoDll $dll)) {
        $release = '2.5.0'
        $package = "php_mongodb-$release-$version-$thread-$compiler-$architecture.zip"
        $url = "https://downloads.php.net/~windows/pecl/releases/mongodb/$release/$package"
        Write-Host "Descargando $package desde PHP.net."
        $null = New-Item -ItemType Directory -Path $downloadDir
        $zip = Join-Path $downloadDir $package
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        $candidate = Join-Path $downloadDir 'php_mongodb.dll'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $entry = $archive.GetEntry('php_mongodb.dll')
            if ($null -eq $entry) { throw 'El paquete de PHP.net no contiene php_mongodb.dll.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $candidate)
        } finally { $archive.Dispose() }
        if (-not (Test-MongoDll $candidate)) {
            throw 'PHP no pudo cargar la DLL descargada. No se aplicó el cambio.'
        }
        if (Test-Path -LiteralPath $dll) { Copy-Item -LiteralPath $dll -Destination $dllBackup }
        Copy-Item -LiteralPath $candidate -Destination $dll -Force
        $dllChanged = $true
    }

    if ((Read-Php @('-m')) -notcontains 'mongodb') {
        Copy-Item -LiteralPath $ini -Destination $iniBackup
        $iniChanged = $true
        [IO.File]::AppendAllText($ini, "`r`n; MongoDB para el tablero de Moodsitto`r`nextension=mongodb`r`n", [Text.Encoding]::ASCII)
    }
    if ((Read-Php @('-m')) -notcontains 'mongodb') { throw 'La DLL se probó, pero PHP no la activó con el archivo de configuración actual.' }
} catch {
    if ($iniChanged) { Copy-Item -LiteralPath $iniBackup -Destination $ini -Force }
    if ($dllChanged) {
        if (Test-Path -LiteralPath $dllBackup) { Copy-Item -LiteralPath $dllBackup -Destination $dll -Force }
        else { Remove-Item -LiteralPath $dll }
    }
    throw
} finally {
    if ($candidate) { Remove-Item -LiteralPath $candidate -ErrorAction SilentlyContinue }
    if ($zip) { Remove-Item -LiteralPath $zip -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $downloadDir) { [IO.Directory]::Delete($downloadDir) }
}

if ($iniChanged) { Write-Host "Respaldo de php.ini guardado en $iniBackup" }
Write-Host 'MongoDB ya está activo. Vuelve a pulsar Iniciar APIcore en el panel.'
