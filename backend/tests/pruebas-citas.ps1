# Pruebas de las citas médicas y los catálogos.
# Necesita al menos un médico, un área y un lugar en la base (sql/catalogos-prueba.sql).
# Uso (con el servidor corriendo en otra terminal):
#   powershell -ExecutionPolicy Bypass -File backend\tests\pruebas-citas.ps1
#   powershell -ExecutionPolicy Bypass -File backend\tests\pruebas-citas.ps1 -Base http://localhost:8002
param([string]$Base = "http://localhost:8000")

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
        $texto = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
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
    }
    $datos = $null
    if ($texto) { try { $datos = $texto | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ Codigo = $codigo; Json = $datos; Texto = $texto }
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

function NuevaCuenta($Nombre) {
    $mail = "$Nombre$Sufijo@moodsitto.invalid"
    $r = Llamar "POST" "/users" @{
        name = $Nombre; lastname1 = "Prueba"; date_b = "2000-05-17"
        phone = "6641234567"; mail = $mail; passw = $Clave
    }
    $id = $r.Json.ID
    $r = Llamar "POST" "/auth/login" @{ mail = $mail; passw = $Clave }
    return [pscustomobject]@{ Id = $id; Token = $r.Json.data.token }
}

$manana = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
$enUnMes = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")

Write-Host "`nProbando citas en $Base`n"
$ana = NuevaCuenta "ana"
$beto = NuevaCuenta "beto"

Write-Host "Catalogos"
$r = Llamar "GET" "/doctores"
Probar "Sin token responde 401" ($r.Codigo -eq 401)
$r = Llamar "GET" "/doctores" $null $ana.Token
Probar "GET /doctores devuelve al menos un medico" (($r.Codigo -eq 200) -and (@($r.Json.data).Count -ge 1))
$idDoctor = @($r.Json.data)[0].id_doctor
$r = Llamar "GET" "/areas" $null $ana.Token
Probar "GET /areas devuelve al menos un area" (($r.Codigo -eq 200) -and (@($r.Json.data).Count -ge 1))
$idArea = @($r.Json.data)[0].id_area
$r = Llamar "GET" "/lugares" $null $ana.Token
Probar "GET /lugares devuelve al menos un lugar" (($r.Codigo -eq 200) -and (@($r.Json.data).Count -ge 1))
$idLugar = @($r.Json.data)[0].id_location

if (-not ($idDoctor -and $idArea -and $idLugar)) {
    Write-Host "`nFaltan datos de catalogo. Corre backend\sql\catalogos-prueba.sql y vuelve a intentar." -ForegroundColor Red
    exit 1
}
$cita = @{ id_doctor = $idDoctor; id_area = $idArea; id_location = $idLugar; fecha = "$manana 10:30"; descripcion = "Primera consulta" }

# Copia de $cita con un campo cambiado (sumar dos @{} con la misma clave falla en PowerShell)
function CitaCon($Campo, $Valor) {
    $copia = $cita.Clone()
    $copia[$Campo] = $Valor
    return $copia
}

Write-Host "`nCrear"
$r = Llamar "POST" "/citas" @{ } $ana.Token
Probar "Sin datos responde 400" ($r.Codigo -eq 400)
$r = Llamar "POST" "/citas" (CitaCon "id_doctor" 99999999) $ana.Token
Probar "Medico inexistente responde 400" (($r.Codigo -eq 400) -and ($r.Texto -match "id_doctor"))
$r = Llamar "POST" "/citas" (CitaCon "id_area" "1") $ana.Token
Probar "Id como texto responde 400" (($r.Codigo -eq 400) -and ($r.Texto -match "id_area"))
$r = Llamar "POST" "/citas" (CitaCon "fecha" "manana") $ana.Token
Probar "Fecha invalida responde 400" (($r.Codigo -eq 400) -and ($r.Texto -match "fecha"))
$r = Llamar "POST" "/citas" $cita $ana.Token
Probar "Cita correcta responde 201" (($r.Codigo -eq 201) -and ($r.Json.ID -gt 0))
$idCita = $r.Json.ID

Write-Host "`nLeer"
$r = Llamar "GET" "/citas" $null $ana.Token
Probar "Listar devuelve la cita" (($r.Codigo -eq 200) -and ($r.Json.meta.total -eq 1))
$r = Llamar "GET" "/citas?desde=$enUnMes" $null $ana.Token
Probar "Filtro desde deja fuera la cita" (($r.Codigo -eq 200) -and ($r.Json.meta.total -eq 0))
$r = Llamar "GET" "/citas/$idCita" $null $ana.Token
Probar "Ver una trae medico, area y lugar con nombre" (($r.Codigo -eq 200) -and $r.Json.data.doctor.nombre -and $r.Json.data.area.nombre -and $r.Json.data.lugar.direccion)
Probar "Una cita nueva empieza pendiente" ($r.Json.data.estado -eq "pendiente")

Write-Host "`nEditar"
$r = Llamar "PATCH" "/citas/$idCita" @{ completado = $true } $ana.Token
Probar "Marcar completada" (($r.Codigo -eq 200) -and ($r.Json.data.estado -eq "completado"))
$r = Llamar "PATCH" "/citas/$idCita" @{ descripcion = "Llevar estudios" } $ana.Token
Probar "PATCH cambia solo la descripcion" (($r.Codigo -eq 200) -and ($r.Json.data.descripcion -eq "Llevar estudios") -and ($r.Json.data.estado -eq "completado"))
$r = Llamar "PATCH" "/citas/$idCita" @{ } $ana.Token
Probar "PATCH vacio responde 400" ($r.Codigo -eq 400)
$sinDescripcion = @{ id_doctor = $idDoctor; id_area = $idArea; id_location = $idLugar; fecha = "$manana 12:00" }
$r = Llamar "PUT" "/citas/$idCita" $sinDescripcion $ana.Token
Probar "PUT reemplaza todo y borra la descripcion" (($r.Codigo -eq 200) -and ($r.Json.data.fecha -eq "$manana 12:00:00") -and ($null -eq $r.Json.data.descripcion))

Write-Host "`nAislamiento entre usuarios (Ana y Beto)"
$r = Llamar "GET" "/citas" $null $beto.Token
Probar "Beto no ve las citas de Ana" (($r.Codigo -eq 200) -and ($r.Json.meta.total -eq 0))
$r = Llamar "GET" "/citas/$idCita" $null $beto.Token
Probar "Beto no puede leer una de Ana (404)" ($r.Codigo -eq 404)
$r = Llamar "PATCH" "/citas/$idCita" @{ completado = $false } $beto.Token
Probar "Beto no puede editar una de Ana (404)" ($r.Codigo -eq 404)
$r = Llamar "DELETE" "/citas/$idCita" $null $beto.Token
Probar "Beto no puede borrar una de Ana (404)" ($r.Codigo -eq 404)

Write-Host "`nBorrar"
$r = Llamar "DELETE" "/citas/$idCita" $null $ana.Token
Probar "Borrar responde 200" ($r.Codigo -eq 200)
$r = Llamar "GET" "/citas/$idCita" $null $ana.Token
Probar "Despues de borrarla responde 404" ($r.Codigo -eq 404)

# Limpieza: desactiva las cuentas de prueba
Llamar "DELETE" "/users/$($ana.Id)" $null $ana.Token | Out-Null
Llamar "DELETE" "/users/$($beto.Id)" $null $beto.Token | Out-Null

Write-Host ""
$color = "Green"
if ($script:mal -gt 0) { $color = "Red" }
Write-Host ("Resultado: " + $script:bien + " correctas, " + $script:mal + " con fallo") -ForegroundColor $color
if ($script:mal -gt 0) { exit 1 }
