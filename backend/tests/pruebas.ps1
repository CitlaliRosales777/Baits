# Pruebas de la API de Moodsitto.
# Uso (con el servidor corriendo en otra terminal):
#   powershell -ExecutionPolicy Bypass -File backend\tests\pruebas.ps1
#   powershell -ExecutionPolicy Bypass -File backend\tests\pruebas.ps1 -Base https://tu-sitio.com
# El puerto 8000 se reserva para APIcore en la presentación.
param([string]$Base = "http://localhost:8001")

$script:bien = 0
$script:mal = 0
$Clave = "Clave-Segura-123"
$Sufijo = Get-Random -Maximum 99999999

function Llamar($Metodo, $Ruta, $Cuerpo = $null, $Token = $null) {
    $cabeceras = @{}
    if ($Token) { $cabeceras["Authorization"] = "Bearer $Token" }
    $p = @{ Uri = "$Base$Ruta"; Method = $Metodo; Headers = $cabeceras; UseBasicParsing = $true }
    if ($Cuerpo -ne $null) {
        $json = $Cuerpo | ConvertTo-Json -Compress
        $p.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $p.ContentType = "application/json; charset=utf-8"
    }
    try {
        $r = Invoke-WebRequest @p
        $codigo = [int]$r.StatusCode
        $texto = $r.Content
        $cab = $r.Headers
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { throw }
        $codigo = [int]$resp.StatusCode
        $texto = ""
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $texto = $_.ErrorDetails.Message
        } else {
            $lector = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $texto = $lector.ReadToEnd()
        }
        $cab = $resp.Headers
    }
    $datos = $null
    if ($texto) { try { $datos = $texto | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ Codigo = $codigo; Json = $datos; Texto = $texto; Cab = $cab }
}

function Probar($Nombre, $Condicion) {
    if ($Condicion) {
        Write-Host ("  OK     " + $Nombre) -ForegroundColor Green
        $script:bien++
    } else {
        Write-Host ("  FALLO  " + $Nombre) -ForegroundColor Red
        $script:mal++
    }
}

function Registrar($Nombre, $Mail) {
    return Llamar "POST" "/users" @{
        name = $Nombre; lastname1 = "Prueba"; date_b = "2000-05-17"
        phone = "6641234567"; mail = $Mail; passw = $Clave
    }
}

function Entrar($Mail, $Pass = $Clave) {
    return Llamar "POST" "/auth/login" @{ mail = $Mail; passw = $Pass }
}

$mailAna = "ana$Sufijo@moodsitto.invalid"
$mailBeto = "beto$Sufijo@moodsitto.invalid"
$mailCarla = "carla$Sufijo@moodsitto.invalid"
$fecha = (Get-Date).AddDays(1).ToString("yyyy-MM-dd") + " 10:00"

Write-Host "`nProbando $Base`n"

Write-Host "Servicio"
$r = Llamar "GET" "/health"
Probar "GET /health responde 200" ($r.Codigo -eq 200)
$r = Llamar "GET" "/ruta-que-no-existe"
Probar "Ruta inexistente responde 404" ($r.Codigo -eq 404)
$r = Llamar "DELETE" "/health"
Probar "Metodo no permitido responde 405" ($r.Codigo -eq 405)
$r = Llamar "OPTIONS" "/users"
Probar "OPTIONS responde 204 con cabecera CORS" (($r.Codigo -eq 204) -and ($r.Cab["Access-Control-Allow-Origin"]))

Write-Host "`nRegistro y login"
$r = Llamar "POST" "/users" @{ }
Probar "Registro sin datos responde 400" ($r.Codigo -eq 400)
$r = Registrar "Ana" $mailAna
Probar "Registro correcto responde 201" ($r.Codigo -eq 201)
$idAna = $r.Json.ID
$r = Registrar "Ana" $mailAna
Probar "Correo repetido responde 409" ($r.Codigo -eq 409)
$r = Entrar $mailAna "contrasena-incorrecta"
Probar "Login con clave mala responde 401" ($r.Codigo -eq 401)
$r = Entrar $mailAna
Probar "Login correcto responde 200 y da token" (($r.Codigo -eq 200) -and ($r.Json.data.token.Length -eq 64))
$tokenAna = $r.Json.data.token

Write-Host "`nPerfil"
$r = Llamar "GET" "/users/$idAna"
Probar "Sin token responde 401" ($r.Codigo -eq 401)
$r = Llamar "GET" "/users/$idAna" $null "token-falso"
Probar "Token falso responde 401" ($r.Codigo -eq 401)
$r = Llamar "GET" "/users/$idAna" $null $tokenAna
Probar "Con token responde 200" ($r.Codigo -eq 200)
Probar "El perfil no incluye la contrasena" ($r.Texto -notmatch "passw")
$r = Llamar "PATCH" "/users/$idAna" @{ phone = "6649998888" } $tokenAna
Probar "PATCH cambia el telefono" (($r.Codigo -eq 200) -and ($r.Json.data.phone -eq "6649998888"))

Write-Host "`nRecordatorios"
$r = Llamar "POST" "/recordatorios" @{ contenido = "Tomar agua"; fecha = $fecha } $tokenAna
Probar "Crear recordatorio responde 201" ($r.Codigo -eq 201)
$idRec = $r.Json.ID
$r = Llamar "POST" "/recordatorios" @{ contenido = "Algo"; fecha = "ayer" } $tokenAna
Probar "Fecha invalida responde 400" ($r.Codigo -eq 400)
$r = Llamar "GET" "/recordatorios" $null $tokenAna
Probar "Listar devuelve el recordatorio" (($r.Codigo -eq 200) -and ($r.Json.meta.total -eq 1))
$r = Llamar "PATCH" "/recordatorios/$idRec" @{ completado = $true } $tokenAna
Probar "Marcar completado" (($r.Codigo -eq 200) -and ($r.Json.data.estado -eq "completado"))
$r = Llamar "PATCH" "/recordatorios/$idRec" @{ completado = $false } $tokenAna
Probar "Volver a pendiente" (($r.Codigo -eq 200) -and ($r.Json.data.estado -eq "pendiente"))

Write-Host "`nAislamiento entre usuarios (Ana y Beto)"
$r = Registrar "Beto" $mailBeto
$idBeto = $r.Json.ID
$r = Entrar $mailBeto
$tokenBeto = $r.Json.data.token
$r = Llamar "GET" "/recordatorios" $null $tokenBeto
Probar "Beto no ve los recordatorios de Ana" (($r.Codigo -eq 200) -and ($r.Json.meta.total -eq 0))
$r = Llamar "GET" "/recordatorios/$idRec" $null $tokenBeto
Probar "Beto no puede leer uno de Ana (404)" ($r.Codigo -eq 404)
$r = Llamar "PATCH" "/recordatorios/$idRec" @{ completado = $true } $tokenBeto
Probar "Beto no puede editar uno de Ana (404)" ($r.Codigo -eq 404)
$r = Llamar "DELETE" "/recordatorios/$idRec" $null $tokenBeto
Probar "Beto no puede borrar uno de Ana (404)" ($r.Codigo -eq 404)
$r = Llamar "GET" "/users/$idAna" $null $tokenBeto
Probar "Beto no puede ver el perfil de Ana (403)" ($r.Codigo -eq 403)

Write-Host "`nSesion"
$r = Llamar "POST" "/auth/logout" $null $tokenAna
Probar "Logout responde 200" ($r.Codigo -eq 200)
$r = Llamar "GET" "/users/$idAna" $null $tokenAna
Probar "El token ya no sirve despues del logout" ($r.Codigo -eq 401)

Write-Host "`nBloqueo por intentos fallidos"
$r = Registrar "Carla" $mailCarla
for ($i = 1; $i -le 5; $i++) { $r = Entrar $mailCarla "mala$i" }
Probar "El quinto intento fallido responde 401" ($r.Codigo -eq 401)
$r = Entrar $mailCarla
Probar "El sexto intento responde 429" ($r.Codigo -eq 429)
Probar "Trae la cabecera Retry-After" ([bool]$r.Cab["Retry-After"])

Write-Host "`nBorrar cuenta"
$r = Entrar $mailAna
$tokenAna2 = $r.Json.data.token
$r = Llamar "DELETE" "/users/$idAna" $null $tokenAna2
Probar "Borrar cuenta responde 200" ($r.Codigo -eq 200)
$r = Entrar $mailAna
Probar "Ya no se puede entrar con la cuenta borrada" ($r.Codigo -eq 401)

Write-Host ""
$color = "Green"
if ($script:mal -gt 0) { $color = "Red" }
Write-Host ("Resultado: " + $script:bien + " correctas, " + $script:mal + " con fallo") -ForegroundColor $color
if ($script:mal -gt 0) { exit 1 }
