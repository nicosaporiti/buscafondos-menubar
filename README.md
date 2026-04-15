# Buscafondos Menubar

App nativa de macOS (menu bar + ventana) para trackear en forma centralizada inversiones en fondos mutuos chilenos de distintas AGFs. Valoriza posiciones, calcula retornos y grafica evolución usando la API pública de [buscafondos](https://api.buscafondos.com) (datos CMF).

---

## Estado actual (v0.1 — en desarrollo)

Build OK en Xcode 15 / macOS 14. El scope v1 (las 4 pantallas de los mockups Stitch) está implementado y navegable, con persistencia local y sincronización de NAVs desde la API real. Quedan pendientes afinamientos de UI en modo ventana y cálculos de retornos reales en el dashboard.

### Funciona
- **Menu bar + ventana draggable**: `MenuBarExtra(.window)` 360×520 con vibrancy + `Window` scene 960×680 accesible desde el botón de expandir del TopBar (`NSApp.setActivationPolicy(.regular)` + `openWindow`).
- **Catálogo CMF**: fetch de `/all-funds` con cache en disco (TTL 24 h) en `Application Support/BuscafondosMenubar/cache`. ~2.900 series, primera carga ~7 s, luego instantánea.
- **Agregar fondo**: búsqueda por nombre / AGF / RUN sobre el catálogo, crea `AGF` + `Fund` en SwiftData y dispara fetch inicial del último NAV.
- **Registrar transacción**: aporte/rescate, selector de fondo, fecha, valor cuota auto-rellenado desde `/real_assets/{id}/days` (pide 7 días hacia atrás y toma el último ≤ fecha elegida, resolviendo fines de semana y feriados), cantidad de cuotas, preview de monto CLP en la tarjeta gradient.
- **Dashboard**: hero balance + bento grid (Today/MTD/Last Month/YTD) + top positions. Los deltas todavía usan valores placeholder (ver pendientes).
- **Gestión de fondos**: lista agrupada por AGF con último valor cuota, cuotas totales y valorización por fondo.
- **Evolución**: Swift Charts con selector de timeframe (1M/3M/6M/1Y/ALL) calculando Σ (cuotas_netas_t × NAV_t) sobre el historial cacheado.
- **Persistencia**: SwiftData local (`AGF`, `Fund`, `FundTransaction`).
- **i18n**: todo el texto en es-CL, formateadores CLP con `NumberFormatter` locale `es_CL`.
- **Tabs sin recrearse**: ZStack + opacity preserva estado (scroll, inputs de formulario, resultados cacheados) al cambiar de tab.

### Pendientes conocidos
- **Dashboard**: Today/MTD/Mes pasado/YTD usan datos dummy — falta `PortfolioCalculator.snapshotDeltas(...)` sobre historial real.
- **UI modo ventana**: el layout del AddFundSheet todavía muestra padding excesivo entre header y search bar cuando la ventana es grande (bug tracking activo).
- **FundSyncService**: refresco automático por timer cada 30 min no está implementado. Actualmente solo se refresca al abrir el popover / tocar sync.
- **Unit tests**: `BuscafondosAPITests` y `PortfolioCalculatorTests` planeados, no escritos.
- **Dark mode**: tokens definidos pero no probado exhaustivamente.

---

## Stack

- **Swift 5.9**, **macOS 14 Sonoma+**, **SwiftUI**
- **SwiftData** (persistencia local)
- **URLSession + async/await** con decoder JSON:API custom
- **Swift Charts** (evolución)
- **XcodeGen** para generar el `.xcodeproj` desde `project.yml`
- `LSUIElement=YES` (accessory app, sin ícono en Dock hasta abrir ventana)

## API — Buscafondos (pública, sin auth)

Base: `https://api.buscafondos.com`

| Endpoint | Uso |
|---|---|
| `GET /health` | timestamp del último scrape |
| `GET /api/asset_providers` | lista de AGFs |
| `GET /api/asset_providers/{id}/conceptual_assets` | fondos de una AGF |
| `GET /api/conceptual_assets/{id}/real_assets` | series con último NAV |
| `GET /api/real_assets/{id}/days?from=&to=` | historial diario |
| `GET /api/real_assets/{id}/expense_ratio` | TAC actual |
| `GET /all-funds` | catálogo completo para búsqueda |

## Estructura

```
BuscafondosMenubar/
  App/                 BuscafondosMenubarApp.swift, AppEnvironment.swift
  Theme/               Theme.swift (Palette, Typography, Spacing, Formatters)
  Models/              AGF.swift, Fund.swift, FundTransaction.swift
  Services/            BuscafondosAPI.swift, JSONAPI.swift, DiskCache.swift,
                       PortfolioCalculator.swift
  Views/
    RootView.swift     VStack(TopBar, ZStack 4-tabs, BottomNavBar)
    Components/        TopBar, BottomNavBar, GlassCard, MoneyText, EmptyStateView
    Dashboard/         DashboardView + hero + bento + top positions
    Funds/             FundsListView, AddFundSheet
    Transactions/      TransactionFormView
    Evolution/         EvolutionView (Swift Charts)
```

## Modelo de datos (SwiftData)

- **`AGF`**: `providerId` (unique), `nombre`, `funds: [Fund]`
- **`Fund`**: `realAssetId` (unique), `conceptId`, `run`, `nombre`, `serie`, `ultimoValorCuota`, `tacAnual`, `agf`, `transacciones: [FundTransaction]`
- **`FundTransaction`**: `fecha`, `tipo` (aporte/rescate), `valorCuota`, `cuotas` (signed), `montoCLP`, `fund`

Holding = derivado (no persistido): `cuotasNetas = Σ transacciones.cuotas`, `valorActual = cuotasNetas × fund.ultimoValorCuota`.

## Diseño — "Institutional Glass"

Sigue `stitch_buscafondos_portfolio_tracker/coda_financial/DESIGN.md`: oceánicos profundos, jerarquía por shifts tonales (sin dividers), tipografía Inter con `monospacedDigit()` para cifras, vibrancy del sistema como base. Tokens en `Theme/Theme.swift`.

Colores clave: `primary #001E40`, `secondary #00629F`, `surface #F8F9FA`, escala `surfaceContainer(Lowest/Low/…/Highest)`.

## Build & run

```bash
# generar .xcodeproj desde project.yml
xcodegen generate

# build desde CLI
xcodebuild -scheme BuscafondosMenubar -configuration Debug -destination 'platform=macOS' build

# lanzar
open ~/Library/Developer/Xcode/DerivedData/BuscafondosMenubar-*/Build/Products/Debug/BuscafondosMenubar.app
```

El ícono aparece en la menu bar (sin Dock). Click para popover 360×520. Botón de expandir del TopBar abre la ventana draggable 960×680.
