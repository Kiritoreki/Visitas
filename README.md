# Visitas Meganet

Registro de visitas técnicas por cliente (piloto): historial tipo "historia clínica", diagnóstico con botones, causa raíz, comparativa cliente vs. técnico, potencia ONU/OLT, etiqueta de roseta, fotos, ubicación GPS, panel y mapa.

- **Administrador** (un solo dispositivo): crea, edita y borra.
- **Solo ver** (el jefe): ve todo, no puede modificar nada. Lo bloquea la base de datos, no solo la pantalla.
- Sin usuarios ni claves: cada celular se autoriza una vez desde Ajustes. Tener el enlace no basta.
- Funciona sin señal: lo que registres se sube solo cuando vuelve el internet.

Sin `config.js` configurado la app corre en **modo demostración** (datos solo en ese celular).

## Configurar Supabase (una sola vez, ~10 min)

1. Entra a <https://supabase.com>, crea una cuenta y un **New project** (plan Free, región *East US* o la más cercana). Guarda la contraseña de la base de datos en un lugar seguro.
2. **SQL Editor › New query**: pega todo el contenido de [`supabase.sql`](supabase.sql) y pulsa **Run**. Debe decir *Success*.
3. **Authentication › Sign In / Providers**: activa **Allow anonymous sign-ins** y guarda.
4. **Project Settings › API**: copia **Project URL** y la clave **anon public**, y pégalas en [`config.js`](config.js).
5. Sube los cambios y sube `VERSION` en `sw.js` (v1 → v2).

## Primer uso

1. En tu iPhone abre el enlace de GitHub Pages en Safari → Compartir → **Agregar a pantalla de inicio**, y ábrela desde el ícono.
2. Ponle un nombre al dispositivo → **Pedir acceso** → **Este dispositivo es el administrador** (solo aparece mientras no exista ninguno).
3. Para el jefe: que haga lo mismo en su celular y te dé el **código de 4 letras**. Tú, en **Ajustes › Dispositivos**, lo marcas como **Solo ver**.

Si un celular borra los datos de Safari o se reinstala la app, pedirá acceso de nuevo: lo vuelves a aprobar y elimina el anterior.

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | Toda la app |
| `config.js` | URL y clave pública de Supabase |
| `supabase.sql` | Tablas, permisos (RLS) y almacenamiento de fotos |
| `sw.js` | Funcionamiento sin internet. Sube `VERSION` en cada cambio |
| `vendor/` | Supabase JS 2.45.4 y Leaflet 1.9.4 (mapa con OpenStreetMap) |

Plan gratuito de Supabase: 500 MB de base de datos y 1 GB de fotos. Cada foto se comprime a ~200–300 KB.
