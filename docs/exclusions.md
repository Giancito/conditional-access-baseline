# Exclusiones y alcance

## Exclusiones transversales

| Grupo | Uso |
|---|---|
| GRP-CA-EXC-EMERGENCIA | Cuentas Break Glass / emergencia |
| GRP-CA-EXC-SERVICIOS | Cuentas de servicio tradicionales excluidas de politicas de usuario |

## Reglas importantes

- GRP-CA-EXC-SERVICIOS no se excluye de CA029 ni CA030.
- Las identidades de carga de trabajo no se excluyen mediante grupos de usuario.
- CA031 y CA032 usan Conditional Access for Workload Identities y requieren Microsoft Entra Workload ID Premium.
- CA001 y CA019 excluyen el rol Directory Synchronization Accounts.
- CA009 aplica a navegador y excluye iOS y Android.
- CA010 bloquea clientes de escritorio de Office 365 en dispositivos no administrados.
- CA013 y CA014 aplican a usuarios estandar solo cuando el dispositivo no es compatible ni unido hibrido.
- Las politicas administrativas de sesion aplican en cualquier ubicacion.
