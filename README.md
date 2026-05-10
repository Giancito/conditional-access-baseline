# Giancito - Línea Base de Acceso Condicional para Microsoft Entra ID

Línea base de Acceso Condicional enfocada en las mejores prácticas y recomendaciones de Microsoft para Microsoft Entra ID, Microsoft 365, Azure y Azure DevOps.

Esta línea base está alineada al modelo Zero Trust y también incorpora criterios prácticos basados en experiencia real en proyectos de consultoría Microsoft en escenarios empresariales, híbridos y cloud.

La documentación visual de las políticas puede generarse con Conditional Access Documenter de Merill / idPowerToys.

https://idpowertoys.merill.net/ca
---

# Objetivo

Esta línea base busca:

- reforzar el acceso a Microsoft 365 y Microsoft Entra ID;
- reducir el uso de autenticación heredada;
- exigir MFA en escenarios críticos;
- controlar acceso desde dispositivos no administrados;
- aplicar controles diferenciados para usuarios, invitados, administradores, cuentas de servicio, workload identities y agentes IA;
- permitir acceso web limitado desde BYOD sin bloquear completamente la productividad;
- proteger Azure, Azure DevOps y Microsoft Graph;
- mantener una estructura clara, reutilizable y fácil de adaptar.

---

# Características principales

- Implementación automatizada mediante Microsoft Graph.
- Compatible con Microsoft Entra ID.
- Compatible con entornos híbridos.
- Despliegue por fases.
- Nomenclatura estandarizada.
- Políticas organizadas por categorías.
- Exclusiones para cuentas break-glass.
- Compatible con Report-only.
- Controles Zero Trust.
- Protección para Azure DevOps.
- Protección para Microsoft Graph.
- Protección para workload identities y agentes IA.

---

# Requisitos

## PowerShell

Se recomienda PowerShell 7 o superior.

```powershell
$PSVersionTable.PSVersion
```

---

## Módulos requeridos

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

---

## Roles requeridos

La cuenta utilizada debe contar con alguno de los siguientes roles:

- Global Administrator
- Conditional Access Administrator
- Security Administrator

---

## Permisos requeridos

El script solicita permisos Microsoft Graph relacionados a:

- Conditional Access
- Groups
- Applications
- Policies
- Directory
- Organization

---

# Licenciamiento

## Microsoft Entra ID P1

Requerido para la mayoría de las políticas:

- MFA
- Named Locations
- Session Controls
- Restricciones por aplicación
- Restricciones por dispositivo
- Bloqueo de autenticación heredada
- MFA resistente a phishing

---

## Microsoft Entra ID P2

Requerido para:

- User Risk
- Sign-in Risk
- Identity Protection

Aplica principalmente a:

- CA010
- CA011

---
# Agentes IA

La política CA032 utiliza la plantilla de Microsoft para identidades de agente con alto riesgo. Su disponibilidad depende de las capacidades habilitadas en el tenant.

---

# Estructura del proyecto

```text
.
├── policies
├── scripts
├── groups
├── namedLocations
├── config
├── documentación
├── docs
├── LICENSE
├── CHANGELOG.md
└── README.md
```

---

# Ejecución

Ir a la carpeta scripts:

```powershell
cd .\scripts
```

Ejecutar:

```powershell
.\Importar-DirectivasCA.ps1
```

---

# Modos de implementación

## Disabled

Crea las políticas deshabilitadas.

---

## Report-only

Permite validar impacto antes de habilitar políticas en producción.

Recomendado para pruebas iniciales y pilotos.

---

## Enabled

Habilita las políticas en producción.

---

# Fases de implementación

```text
[1] Usuarios base
[2] Invitados
[3] Administradores
[4] Cuentas de servicio
[5] Identidades de carga de trabajo
[6] Agentes IA
[7] Todas las políticas
```

---

# Grupos creados

| Grupo | Uso |
|---|---|
| GRP-CA-EXC-EMERGENCIA | Exclusión break-glass |
| GRP-CA-EXC-SERVICIOS | Exclusión cuentas de servicio |
| GRP-CA-EXC-TEMPORAL | Exclusiones temporales |
| GRP-CA-CUENTAS-SERVICIO | Protección cuentas de servicio |

---

# Ubicaciones con nombre

| Ubicación | Uso |
|---|---|
| PAISES PERMITIDOS | Países autorizados |
| PAISES PERMITIDOS - CUENTAS DE SERVICIO | Países permitidos para cuentas de servicio |
| UBICACIONES CONFIANZA - CUENTAS DE SERVICIO | IPs confiables cuentas de servicio |
| UBICACIONES CONFIANZA - IDENTIDADES DE CARGA DE TRABAJO | IPs confiables workload identities |

---

# Nomenclatura

Formato utilizado:

```text
CA### - Aplicación o recurso - Acción - Alcance - Condición
```

Ejemplo:

```text
CA006 - Microsoft 365 - Requerir dispositivo compatible o unido híbrido - Para usuarios Windows
```

---

# Detalle de políticas

## CA001 - Todas las aplicaciones en la nube - Requerir MFA - Para todos los usuarios

Solicita autenticación multifactor para todos los usuarios cuando acceden a aplicaciones protegidas por Microsoft Entra ID.

---

## CA002 - Todas las aplicaciones en la nube - Bloquear autenticación heredada - Para todos los usuarios

Bloquea protocolos de autenticación heredada que no soportan MFA moderno.

---

## CA003 - Todas las aplicaciones en la nube - Bloquear acceso - Para todos los usuarios - Cuando se use Device Code Flow

Bloquea autenticaciones mediante Device Code Flow.

---

## CA004 - Todas las aplicaciones en la nube - Bloquear acceso - Para todos los usuarios - Cuando se use Authentication Transfer

Bloquea autenticaciones mediante Authentication Transfer.

---

## CA005 - Todas las aplicaciones en la nube - Bloquear acceso - Para todos los usuarios - Cuando el acceso provenga de países no permitidos

Bloquea accesos desde ubicaciones geográficas no autorizadas.

---

## CA006 - Microsoft 365 - Requerir dispositivo compatible o unido híbrido - Para usuarios Windows

Permite acceso a Microsoft 365 únicamente desde dispositivos Windows compliant o Hybrid Joined.

La política aplica solamente a:

```text
Mobile apps and desktop clients
```

No aplica a navegadores web, ya que el acceso web desde dispositivos no administrados se controla mediante CA009.

Esto permite mantener un enfoque Zero Trust sin bloquear completamente escenarios BYOD.

---

## CA007 - Microsoft 365 - Requerir dispositivo compatible - Para usuarios macOS

Permite acceso a Microsoft 365 desde macOS únicamente si el dispositivo está administrado y compliant.

---

## CA008 - Aplicaciones móviles - Requerir App Protection Policy - Para usuarios móviles

Exige App Protection Policy para dispositivos móviles Android e iOS.

---

## CA009 - SharePoint Online - Restringir acceso - Para dispositivos no administrados

Aplica restricciones de sesión sobre SharePoint Online y OneDrive desde navegadores web en dispositivos no administrados.

Excluye automáticamente:

- dispositivos Hybrid Joined;
- dispositivos compliant.

Complementa CA006 para proteger el acceso web desde BYOD.

---

## CA010 - Todas las aplicaciones en la nube - Bloquear acceso - Para usuarios con alto riesgo

Bloquea acceso a usuarios detectados con riesgo alto por Microsoft Entra ID Protection.

---

## CA011 - Todas las aplicaciones en la nube - Bloquear acceso - Para inicios de sesión de alto riesgo

Bloquea autenticaciones clasificadas con riesgo alto por Microsoft Entra ID Protection.

---

## CA012 - Todas las aplicaciones en la nube - Requerir reautenticación - Para usuarios - Cada 12 horas

Solicita reautenticación cada 12 horas para reducir persistencia de sesiones activas.

---

## CA013 - Todas las aplicaciones en la nube - Deshabilitar sesión persistente del navegador - Para usuarios - Cuando el dispositivo no esté administrado

Evita sesiones persistentes de navegador en dispositivos no administrados.

---

## CA014 - Todas las aplicaciones en la nube - Habilitar Continuous Access Evaluation - Para usuarios

Habilita reevaluación continua de sesiones mediante Continuous Access Evaluation.

---

## CA015 - Linux - Bloquear acceso - Para dispositivos no administrados

Bloquea acceso desde Linux no administrado.

---

## CA016 - Microsoft Graph Explorer - Bloquear acceso - Para todos los usuarios

Bloquea acceso a Microsoft Graph Explorer.

---

## CA017 - Microsoft Graph PowerShell - Bloquear acceso - Para usuarios no administradores

Bloquea Microsoft Graph PowerShell para usuarios sin roles administrativos autorizados.

---

## CA018 - Registrar o unir dispositivos - Requerir MFA - Para todos los usuarios

Solicita MFA al registrar o unir dispositivos a Microsoft Entra ID.

---

## CA019 - Todas las aplicaciones en la nube - Requerir MFA - Para invitados

Solicita MFA a usuarios invitados o externos.

---

## CA020 - Aplicaciones seleccionadas - Bloquear acceso - Para invitados no aprobados

Bloquea acceso de invitados externos no autorizados.

---

## CA021 - Todas las aplicaciones en la nube - Requerir MFA resistente a phishing - Para administradores

Exige métodos MFA resistentes a phishing para cuentas administrativas.

---

## CA022 - Todas las aplicaciones en la nube - Requerir dispositivo compatible o unido híbrido - Para administradores

Permite acceso administrativo únicamente desde dispositivos confiables.

---

## CA023 - Todas las aplicaciones en la nube - Requerir reautenticación - Para administradores - Cada 4 horas

Solicita reautenticación periódica para cuentas administrativas.

---

## CA024 - Todas las aplicaciones en la nube - Deshabilitar sesión persistente del navegador - Para administradores

Deshabilita sesiones persistentes para cuentas administrativas.

---

## CA025 - Todas las aplicaciones en la nube - Habilitar Continuous Access Evaluation - Para administradores

Habilita Continuous Access Evaluation para cuentas administrativas.

---

## CA026 - Administración de Microsoft Azure - Requerir MFA - Para todos los usuarios

Solicita MFA para acceder a la administración de Microsoft Azure.

---

## CA027 - Azure DevOps - Requerir MFA - Para todos los usuarios

Solicita MFA para acceso a Azure DevOps.

---

## CA028 - Todas las aplicaciones en la nube - Bloquear acceso - Para cuentas de servicio - Cuando el acceso provenga de países no permitidos

Bloquea cuentas de servicio desde países no autorizados.

---

## CA029 - Todas las aplicaciones en la nube - Requerir ubicación confiable - Para cuentas de servicio

Permite acceso de cuentas de servicio únicamente desde ubicaciones IP confiables.

---

## CA030 - Todas las aplicaciones en la nube - Requerir ubicación confiable - Para identidades de carga de trabajo

Permite acceso de workload identities únicamente desde ubicaciones autorizadas.

---

## CA031 - Todas las aplicaciones en la nube - Bloquear acceso - Para identidades de carga de trabajo - Cuando el riesgo sea alto

Bloquea workload identities detectadas con riesgo alto.

---

## CA032 - Todas las aplicaciones en la nube - Bloquear acceso - Para agentes IA - Cuando el riesgo sea alto

Bloquea acceso cuando Microsoft Entra detecta que una identidad de agente presenta riesgo alto.

---

# Recomendaciones de despliegue

## Implementar inicialmente en Report-only

Antes de habilitar políticas en producción:

- revisar Sign-in Logs;
- validar aplicaciones heredadas;
- revisar impacto en usuarios;
- validar cuentas de servicio;
- revisar dispositivos personales;
- validar exclusiones.

---

## Utilizar cuentas break-glass

Mantener cuentas de emergencia excluidas de políticas críticas.

---

## Despliegue gradual

Orden recomendado:

1. MFA
2. bloqueo autenticación heredada
3. restricciones por dispositivo
4. session controls
5. Identity Protection
6. administradores
7. workload identities
8. agentes IA

---

## Acciones protegidas recomendadas

Se recomienda habilitar Protected Actions para reforzar operaciones sensibles relacionadas a:

- políticas de Acceso Condicional;
- métodos de autenticación;
- cambios administrativos críticos.

---

# Referencia visual

Representación visual generada con:

```text
https://idpowertoys.merill.net/ca
```
