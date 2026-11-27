# Las cuatro cuentas de aplicación se guardan cifradas para el usuario de Windows que usa el panel.
$script:AccessFolder = Join-Path $env:LOCALAPPDATA 'Moodsitto'
$script:AccessFile = Join-Path $script:AccessFolder 'presentacion.credential.xml'
$script:PairFile = Join-Path $script:AccessFolder 'solicitud-pendiente.credential.xml'
$script:AccessUsers = [ordered]@{
    apicoreMaria = 'apicore_app'
    apicoreMongo = 'apicore_emociones'
    panelMaria = 'moodsitto_app'
    panelMongo = 'moodsitto_app'
}

function Get-PresentationAccess {
    if (Test-Path -LiteralPath $script:AccessFile) {
        $access = Import-Clixml -LiteralPath $script:AccessFile
        foreach ($key in $script:AccessUsers.Keys) {
            if ($access[$key] -isnot [pscredential] -or $access[$key].UserName -ne $script:AccessUsers[$key] -or
                $access[$key].Password.Length -eq 0) { throw 'El acceso guardado está incompleto. Vuelve a importar el paquete.' }
        }
        $access
    }
}

function Get-ApiCoreAccess {
    $access = Get-PresentationAccess
    if ($access) { return @{ Maria = $access.apicoreMaria; Mongo = $access.apicoreMongo } }

    # El Windows fijo conserva las credenciales que se crearon antes del panel.
    $sql = Join-Path $script:AccessFolder 'apicore-demo.credential.xml'
    $mongo = Join-Path $script:AccessFolder 'apicore-emociones.credential.xml'
    if ((Test-Path -LiteralPath $sql) -and (Test-Path -LiteralPath $mongo)) {
        return @{ Maria = (Import-Clixml -LiteralPath $sql); Mongo = (Import-Clixml -LiteralPath $mongo) }
    }
}

function Get-AccessInbox {
    $inbox = Join-Path $script:AccessFolder 'Recibidos'
    $null = New-Item -ItemType Directory -Path $inbox -Force
    $inbox
}

function Find-PresentationTransfer {
    param([string]$Name, [string]$Inbox)
    $folders = @($Inbox)
    $knownFolders = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
    $downloads = $knownFolders.'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($downloads) { $folders += [Environment]::ExpandEnvironmentVariables($downloads) }
    $folders += Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    # Tailscale para Windows también puede guardar los archivos directamente en Descargas.
    foreach ($folder in $folders) {
        $path = Join-Path $folder $Name
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
}

function Get-PresentationRequestId {
    param([string]$PublicKey)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        # El código identifica la clave pública, así la otra máquina puede comprobar que sea la correcta.
        [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($PublicKey))).Replace('-', '').Substring(0, 32).ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function New-PresentationRequest {
    if ($env:COMPUTERNAME -ine 'DESKTOP-0DDRLDI') {
        throw 'La solicitud se genera en la laptop DESKTOP-0DDRLDI que usará el acceso.'
    }
    $null = New-Item -ItemType Directory -Path $script:AccessFolder -Force
    $rsa = [Security.Cryptography.RSACng]::new(3072)
    try {
        $public = $rsa.ToXmlString($false)
        $requestId = Get-PresentationRequestId $public
        $private = ConvertTo-SecureString ($rsa.ToXmlString($true)) -AsPlainText -Force
        @{ Id = $requestId; PrivateKey = $private } | Export-Clixml -LiteralPath $script:PairFile
        $request = Join-Path $script:AccessFolder "moodsitto-solicitud-$requestId.json"
        @{ Id = $requestId; PublicKey = $public } | ConvertTo-Json -Compress | Set-Content -LiteralPath $request -Encoding UTF8
        try {
            & tailscale file cp $request '100.89.172.17:' | Out-Null
            if ($LASTEXITCODE) { throw 'Tailscale no pudo enviar la solicitud al Windows fijo.' }
        } catch {
            Remove-Item -LiteralPath $script:PairFile -ErrorAction SilentlyContinue
            throw
        } finally { Remove-Item -LiteralPath $request }
    } finally { $rsa.Dispose() }
    $requestId
}

function New-PresentationPackage {
    param([string]$RequestPath, [string]$RequestId, [hashtable]$Credentials)
    if ($RequestId -notmatch '^[0-9a-f]{32}$') { throw 'El código de solicitud no tiene el formato esperado.' }
    $request = Get-Content -Raw -LiteralPath $RequestPath -Encoding UTF8 | ConvertFrom-Json
    if ($request.Id -cne $RequestId -or
        $request.PublicKey -cnotmatch '^<RSAKeyValue><Modulus>[A-Za-z0-9+/=]+</Modulus><Exponent>[A-Za-z0-9+/=]+</Exponent></RSAKeyValue>$' -or
        (Get-PresentationRequestId $request.PublicKey) -cne $RequestId) {
        throw 'La solicitud no coincide con el código de la laptop.'
    }
    $rsa = [Security.Cryptography.RSACng]::new()
    try {
        $rsa.FromXmlString($request.PublicKey)
        if ($rsa.KeySize -lt 3072) { throw 'La solicitud debe usar una llave de al menos 3072 bits.' }
        $encrypted = @{}
        foreach ($key in $script:AccessUsers.Keys) {
            if ($Credentials[$key] -isnot [pscredential] -or $Credentials[$key].Password.Length -eq 0) {
                throw "Falta configurar la cuenta $key en el Windows fijo."
            }
            $message = [Text.Encoding]::UTF8.GetBytes($Credentials[$key].GetNetworkCredential().Password)
            try {
                $encrypted[$key] = [Convert]::ToBase64String($rsa.Encrypt($message, [Security.Cryptography.RSAEncryptionPadding]::OaepSHA256))
            } finally { [Array]::Clear($message, 0, $message.Length) }
        }
        @{ Id = $RequestId; Ciphertext = $encrypted } | ConvertTo-Json -Compress
    } finally { $rsa.Dispose() }
}

function Import-PresentationPackage {
    param([string]$Path, [hashtable]$Pair)
    $package = Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
    if ($Pair.Id -notmatch '^[0-9a-f]{32}$' -or $package.Id -cne $Pair.Id) { throw 'El paquete no corresponde a la solicitud de esta laptop.' }
    $access = @{}
    $rsa = [Security.Cryptography.RSACng]::new()
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pair.PrivateKey)
    try {
        $rsa.FromXmlString([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr))
        foreach ($key in $script:AccessUsers.Keys) {
            $message = $rsa.Decrypt([Convert]::FromBase64String($package.Ciphertext.PSObject.Properties[$key].Value),
                [Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
            try {
                $secret = ConvertTo-SecureString ([Text.Encoding]::UTF8.GetString($message)) -AsPlainText -Force
                $access[$key] = [pscredential]::new($script:AccessUsers[$key], $secret)
            } finally { [Array]::Clear($message, 0, $message.Length) }
        }
        $temp = "$script:AccessFile.$($Pair.Id).tmp"
        $previous = "$temp.previous"
        try {
            $access | Export-Clixml -LiteralPath $temp
            if (Test-Path -LiteralPath $script:AccessFile) {
                [IO.File]::Replace($temp, $script:AccessFile, $previous)
                Remove-Item -LiteralPath $previous -ErrorAction SilentlyContinue
            }
            else { [IO.File]::Move($temp, $script:AccessFile) }
        } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $rsa.Dispose()
    }
}

function Receive-PresentationAccess {
    if (-not (Test-Path -LiteralPath $script:PairFile)) { throw 'Pulsa Solicitar accesos en esta laptop primero.' }
    $pair = Import-Clixml -LiteralPath $script:PairFile
    $inbox = Get-AccessInbox
    & tailscale file get $inbox | Out-Null
    $package = Find-PresentationTransfer "moodsitto-accesos-$($pair.Id).json" $inbox
    if (-not $package) { throw 'Todavía no llegó el paquete del Windows fijo. Conserva esta solicitud y vuelve a intentar Recibir accesos.' }
    Import-PresentationPackage $package $pair
    Remove-Item -LiteralPath $package, $script:PairFile
}
