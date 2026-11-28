# Cuenta independiente para los registros ficticios de este usuario de Windows.
$script:PanelDataCredentialPath = Join-Path $env:LOCALAPPDATA 'Moodsitto\datos-prueba.credential.xml'
$script:PanelDataToken = $null
$script:PendingPanelData = @{}

function Get-PanelDataCredential {
    param([switch]$Create)
    $path = $script:PanelDataCredentialPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        if (-not $Create) { return }
        $id = [Guid]::NewGuid().ToString('N').Substring(0, 12)
        $secret = New-PresentationSecureString (('Ensayo#9-' + [Guid]::NewGuid().ToString('N')).ToCharArray())
        $credential = [pscredential]::new("moodsitto-panel+$id@example.invalid", $secret)
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        $temp = "$path.$id.tmp"
        try {
            $credential | Export-Clixml -LiteralPath $temp
            try { [IO.File]::Move($temp, $path) }
            catch [IO.IOException] { if (-not [IO.File]::Exists($path)) { throw } }
        } finally {
            [IO.File]::Delete($temp)
            $secret.Dispose()
        }
    }
    $saved = Import-Clixml -LiteralPath $path
    if ($saved -isnot [pscredential] -or $saved.UserName -cnotmatch '^moodsitto-panel\+[0-9a-f]{12}@example\.invalid$' -or
        $saved.Password.Length -eq 0) { throw 'No se pudo validar la cuenta ficticia del panel.' }
    $saved
}

function Invoke-PanelDataRequest {
    param([string]$Method, [string]$Path, $Body, [string]$Token)
    $ProgressPreference = 'SilentlyContinue'
    $options = @{ Uri = "http://localhost:8000$Path"; Method = $Method; TimeoutSec = 7; ErrorAction = 'Stop' }
    if ($Token) { $options.Headers = @{ Authorization = "Bearer $Token" } }
    if ($null -ne $Body) {
        $options.ContentType = 'application/json; charset=utf-8'
        $options.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 7 -Compress))
    }
    try {
        $response = Invoke-WebRequest @options -UseBasicParsing
        # APIcore puede devolver application/json sin charset. El JSON de la API usa UTF-8.
        $json = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
        $data = $json | ConvertFrom-Json
        [pscustomobject]@{ Status = [int]$response.StatusCode; Data = $data }
    } catch {
        # Los cuerpos de error pueden contener detalles de la aplicación. Solo se muestra el código HTTP.
        $response = $_.Exception.Response
        $status = if ($response) { [int]$response.StatusCode } else { 0 }
        [pscustomobject]@{ Status = $status; Data = $null }
    }
}

function Get-PanelDataToken {
    param([pscredential]$Credential)
    if ($script:PanelDataToken) { return $script:PanelDataToken }
    $login = @{ Email = $Credential.UserName; Password = $Credential.GetNetworkCredential().Password }
    $result = Invoke-PanelDataRequest POST '/auth/login' -Body $login
    if ($result.Status -eq 401) {
        # Permite recuperar una creación interrumpida con la misma credencial protegida.
        $account = $login + @{ Name = 'Ensayo'; PaternalSurname = 'Panel'; BirthDate = '2000-01-01'; UserStatus = 'Active' }
        $created = Invoke-PanelDataRequest POST '/users' -Body $account
        $result = Invoke-PanelDataRequest POST '/auth/login' -Body $login
        if (-not $result.Data.data.token -and $created.Status -notin 200, 201) {
            throw "APIcore no pudo crear la cuenta ficticia (HTTP $($created.Status))."
        }
    }
    if ($result.Status -eq 0) { throw 'APIcore no respondió en el puerto 8000. Comprueba Inicio local → Ver estado.' }
    if (-not $result.Data.data.token) { throw "APIcore no pudo iniciar la sesión de prueba (HTTP $($result.Status))." }
    $script:PanelDataToken = $result.Data.data.token
    $script:PanelDataToken
}

function Invoke-PanelData {
    param([ValidateSet('GET','PUT')][string]$Method, [string]$Path, $Body)
    $credential = Get-PanelDataCredential -Create:($Method -eq 'PUT')
    if (-not $credential) { return }
    $token = Get-PanelDataToken $credential
    $result = Invoke-PanelDataRequest $Method $Path -Body $Body -Token $token
    if ($result.Status -eq 401) {
        $script:PanelDataToken = $null
        $token = Get-PanelDataToken $credential
        $result = Invoke-PanelDataRequest $Method $Path -Body $Body -Token $token
    }
    if ($result.Status -eq 0) { throw 'APIcore no respondió en el puerto 8000. Comprueba Inicio local → Ver estado.' }
    if ($result.Status -ne 200) { throw "APIcore devolvió HTTP $($result.Status) durante $Method $Path." }
    $result.Data.data
}

function Save-PanelDataEntry {
    param([ValidateSet('emociones','recordatorios')][string]$Collection, $Body)
    $content = $Body | ConvertTo-Json -Depth 7 -Compress
    $pending = $script:PendingPanelData[$Collection]
    if (-not $pending -or $pending.Content -cne $content) {
        $pending = @{ Id = [Guid]::NewGuid().ToString(); Content = $content }
        $script:PendingPanelData[$Collection] = $pending
    }
    # Si el servidor aplicó un envío que expiró, repetir el mismo contenido conserva el identificador.
    Invoke-PanelData PUT "/tablero/$Collection/$($pending.Id)" $Body | Out-Null
    $script:PendingPanelData.Remove($Collection)
    $pending.Id
}

# El orden coincide con las celdas de iconos-cartas.png.
$script:PanelCatalogIcons = [ordered]@{
    general = 'Corazón con pulso'
    miedo = 'Ojo'
    enojo = 'Rayo'
    tristeza = 'Gota'
    alegria = 'Sol'
    poder = 'Montaña'
    paz = 'Luna'
}

function New-PanelCatalogCard {
    param([string]$Name, [string]$Description, [string]$Color, [string]$Details, [string]$Icon = 'general')
    $name = $Name.Trim()
    $description = $Description.Trim()
    $color = $Color.Trim()
    if (-not $name -or $name.Length -gt 80 -or -not $description -or $description.Length -gt 1000) {
        throw 'Escribe un nombre de hasta 80 caracteres y una descripción de hasta 1000.'
    }
    if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'Usa un color hexadecimal, por ejemplo #D4A8E8.' }
    if ($Icon -cnotin $script:PanelCatalogIcons.Keys) { throw 'Selecciona un icono del catálogo.' }
    $key = [regex]::Replace($name.Normalize([Text.NormalizationForm]::FormD), '\p{Mn}', '').ToLowerInvariant()
    $key = ([regex]::Replace($key, '[^a-z0-9]+', '-')).Trim('-')
    if (-not $key) { throw 'Incluye letras o números en el nombre de la carta.' }

    $matices = @()
    $seen = @{}
    $usedDetails = @{}
    foreach ($line in ($Details -split '\r?\n')) {
        if (-not $line.Trim()) { continue }
        $parts = @($line.Split('|') | ForEach-Object { $_.Trim() })
        if ($parts.Count -gt 4 -or @($parts | Where-Object { -not $_ -or $_.Length -gt 80 }).Count) {
            throw 'En cada línea escribe un matiz y hasta tres detalles separados por |. Cada texto admite hasta 80 caracteres.'
        }
        if ($seen.ContainsKey($parts[0])) { throw "El matiz «$($parts[0])» está repetido." }
        $seen[$parts[0]] = $true
        $more = @($parts | Select-Object -Skip 1)
        foreach ($detail in $more) {
            if ($usedDetails.ContainsKey($detail)) { throw "El detalle «$detail» está repetido." }
            $usedDetails[$detail] = $true
        }
        $matices += @{ nombre = $parts[0]; detalles = $more }
    }
    # El historial admite hasta veinte etiquetas por nivel.
    if ($matices.Count -gt 6) { throw 'Agrega hasta seis matices, uno por línea.' }
    @{
        codigo = $key; nombre = $name; descripcion = $description; color = $color; icono = $Icon
        nivel = 'central'; parent_codigo = $null; activo = $true; orden = 100; matices = $matices
    }
}

function Get-PanelCatalogCards {
    $result = Invoke-MongoEval @'
const cartas = db.catalogo_emociones.find(
  { nivel: "central" },
  { _id: 0, codigo: 1, nombre: 1, descripcion: 1, color: 1, icono: 1, activo: 1, matices: 1, updated_at: 1 }
).sort({ nombre: 1, codigo: 1 }).toArray();
print(JSON.stringify(cartas.map(({ updated_at, ...carta }) => ({ ...carta, revision: updated_at.getTime() }))));
'@
    $cards = $result.Output | ConvertFrom-Json
    foreach ($card in $cards) { $card }
}

function Save-PanelCatalogCard {
    param([hashtable]$Card, $Existing)
    if ($Existing) {
        $changes = @{
            nombre = $Card.nombre; descripcion = $Card.descripcion; color = $Card.color; icono = $Card.icono
            matices = $Card.matices; activo = $Card.activo
        } | ConvertTo-Json -Depth 6 -Compress
        $key = ConvertTo-Json -InputObject $Existing.codigo -Compress
        $revision = [long]$Existing.revision
        $javascript = @"
const filtro = { codigo: $key, nivel: "central" };
const cambios = $changes;
const anterior = db.catalogo_emociones.findOne(filtro);
if (!anterior) throw new Error("La carta ya no está en el catálogo.");
if (anterior.updated_at.getTime() !== $revision) {
  const mismosMatices = JSON.stringify((anterior.matices || []).map(m => [m.nombre, m.detalles]))
    === JSON.stringify(cambios.matices.map(m => [m.nombre, m.detalles]));
  const mismoContenido = mismosMatices && ["nombre", "descripcion", "color", "activo"]
    .every(campo => anterior[campo] === cambios[campo]) && (anterior.icono || "general") === cambios.icono;
  if (!mismoContenido) throw new Error("Otra sesión cambió esta carta. Reabre el catálogo antes de editarla.");
} else {
  const resultado = db.catalogo_emociones.updateOne(
    { ...filtro, updated_at: new Date($revision) },
    { `$set: { ...cambios, updated_at: new Date(Math.max(Date.now(), $revision + 1)) } },
    { writeConcern: { w: "majority", wtimeout: 5000 } }
  );
  if (!resultado.matchedCount) throw new Error("Otra sesión cambió esta carta. Reabre el catálogo antes de editarla.");
}
const guardada = db.catalogo_emociones.findOne(filtro, { _id: 0, codigo: 1, nombre: 1, activo: 1, icono: 1 });
print(JSON.stringify({ ...guardada, icono: guardada.icono || "general" }));
"@
        $result = Invoke-MongoEval $javascript
        $result.Output | ConvertFrom-Json
        return
    }
    $json = $Card | ConvertTo-Json -Depth 6 -Compress
    $javascript = @"
const carta = $json;
const filtro = { codigo: carta.codigo };
const anterior = db.catalogo_emociones.findOne(filtro);
if (anterior) {
  const mismaCarta = Object.keys(carta).every(campo => {
    if (campo === "icono") return (anterior.icono || "general") === carta.icono;
    if (campo === "matices") {
      return JSON.stringify((anterior.matices || []).map(m => [m.nombre, m.detalles]))
        === JSON.stringify(carta.matices.map(m => [m.nombre, m.detalles]));
    }
    return anterior[campo] === carta[campo];
  });
  if (!mismaCarta) throw new Error("Ya existe una carta con ese código.");
} else {
  const ahora = new Date();
  const resultado = db.catalogo_emociones.updateOne(
    filtro,
    { `$setOnInsert: { ...carta, created_at: ahora, updated_at: ahora } },
    { upsert: true, writeConcern: { w: "majority", wtimeout: 5000 } }
  );
  if (!resultado.upsertedCount) throw new Error("Ya existe una carta con ese código.");
}
const guardada = db.catalogo_emociones.findOne(filtro, { _id: 0, codigo: 1, nombre: 1, activo: 1, icono: 1 });
print(JSON.stringify({ ...guardada, icono: guardada.icono || "general" }));
"@
    $result = Invoke-MongoEval $javascript
    $result.Output | ConvertFrom-Json
}

function Get-PanelDataQuery {
    param([ValidateSet('emociones','recordatorios')][string]$Collection, [switch]$Write, [string]$RecordId)
    # Estas consultas corresponden a Services/DatosTablero.php de APIcore.
    $lines = if ($Collection -eq 'recordatorios') {
        if ($Write) {
            @'
SQL preparado · apicore
INSERT INTO tablero_recordatorios
  (user_id, recordatorio_id, detalle)
VALUES (?, ?, ?)
ON DUPLICATE KEY UPDATE detalle = VALUES(detalle);

Los parámetros reciben el ID de la cuenta, el ID del registro y el detalle JSON.

Lectura de comprobación
'@
        }
        @'
SELECT recordatorio_id, detalle
FROM tablero_recordatorios
WHERE user_id = ?
ORDER BY creado_at, recordatorio_id;

El parámetro es el ID de la cuenta ficticia.
'@
    } else {
        if ($Write) {
            @'
Equivalente en mongosh · moodsitto
db.historial_emociones_apicore.updateOne(
  { apicore_user_id: idCuenta, registro_id: idRegistro },
  { $setOnInsert: { creado_at: new Date(), grupo: emociones } },
  { upsert: true, writeConcern: { w: "majority", wtimeout: 5000 } }
);

Lectura de comprobación
'@
        }
        @'
db.historial_emociones_apicore
  .find({ apicore_user_id: idCuenta })
  .sort({ creado_at: -1, registro_id: -1 })
  .limit(100);

idCuenta se obtiene de la cuenta ficticia autenticada.
'@
    }
    $route = if ($Write) {
        $id = if ($RecordId) { $RecordId } else { '<id de registro>' }
        "PUT /tablero/$Collection/$id"
    } else { "GET /tablero/$Collection" }
    if ($Collection -eq 'recordatorios' -and -not $Write) { $route += "`r`nSQL preparado · apicore" }
    if ($Collection -eq 'emociones' -and -not $Write) { $route += "`r`nEquivalente en mongosh · moodsitto" }
    $text = (@($route, '') + @($lines)) -join "`r`n"
    # Los cuadros de texto de Windows Forms necesitan CRLF para conservar las líneas.
    $text -replace "`r?`n", "`r`n"
}
