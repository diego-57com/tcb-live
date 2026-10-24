# TCB Live

App Android (Flutter) para ver os autocarros da **TCB — Transportes Colectivos do Barreiro**:
paragens, carreiras, horários, "próximas passagens" por paragem e — opcionalmente —
posições em tempo real num mapa OpenStreetMap, com um design mais limpo do que a app oficial.

> ⚠️ Projeto independente, não afiliado à TCB.

## O que faz

- 🗺️ **Mapa** (OpenStreetMap via `flutter_map`, sem chave de API) com todas as paragens e, se ativado, os autocarros em direto.
- 🚏 **Paragens** — pesquisa por nome/número, favoritas e "próximas de mim".
- ⏱️ **Próximas passagens** por paragem, calculadas a partir do horário GTFS (com contagem decrescente).
- 🚌 **Carreiras** — lista de linhas, variantes/destinos, trajeto no mapa e paragens por ordem.
- ⭐ **Favoritos** persistidos.
- 📡 **Tempo real plugável** — camada genérica que lê posições de um endpoint JSON (ver abaixo).

## Dados e licença

- **GTFS estático** (paragens, carreiras, horários, shapes): TCB, licença
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). URL oficial:
  `https://backend.tcbarreiro.pt/download-gtfs` (a app descarrega e faz cache automaticamente).
- **Mapa**: tiles © OpenStreetMap contributors.
- **Tempo real**: a TCB **não publica** um feed aberto de posições (GTFS-RT). O "mapa em
  direto" do site usa um backend privado. A app está pronta para consumir esse endpoint
  **se tu o configurares** (passo a passo abaixo). Sem isso, tudo o resto funciona na mesma
  (horários + próximas passagens baseadas no horário).

## 🚀 Obter o APK sem instalar nada no PC

Não precisas de instalar Flutter, Android Studio nem nada. O **GitHub** compila o APK por ti
(usando o workflow já incluído em [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml)).

1. Cria uma conta grátis em [github.com](https://github.com) (se ainda não tens).
2. Cria um repositório novo: **New repository** → nome (ex.: `tcb-live`) → **Create repository**.
3. Faz upload do projeto:
   - No repositório: **Add file → Upload files**.
   - Arrasta **todo o conteúdo da pasta `tcb_live/`** (`lib/`, `pubspec.yaml`, `analysis_options.yaml`, `README.md`…).
   - **Commit changes**.
4. Garante que o workflow existe (o GitHub por vezes ignora pastas que começam por `.`):
   - **Add file → Create new file** → nome: `.github/workflows/build-apk.yml`
   - Cola o conteúdo de [`build-apk.yml`](.github/workflows/build-apk.yml) → **Commit changes**.
5. O build arranca sozinho. Vai a **Actions** → clica no run verde → em baixo, em **Artifacts**,
   descarrega **`tcb-live-apk`** (vem num `.zip`).
6. Descomprime, passa o `app-release.apk` para o telemóvel (Google Drive, email, WhatsApp ou cabo USB)
   e instala. O Android vai pedir para permitir "instalar de fontes desconhecidas" — permite.

> A primeira compilação demora 3–6 minutos. Se aparecer ❌, clica no run para ver o erro
> (normalmente é só ajustar uma versão no `pubspec.yaml`).

## Para developers: correr localmente (opcional)

Só se quiseres editar o código e testar no teu PC (precisas de Flutter + Android Studio):

1. Gera o scaffolding Android (caso ainda não exista a pasta `android/`):

   ```bash
   cd tcb_live
   flutter create --platforms=android --project-name tcb_live .
   ```

2. Instala as dependências e corre:

   ```bash
   flutter pub get
   flutter run
   ```

### Permissões Android (para quem compila localmente em release)

- **Internet** (necessária para o mapa e o GTFS). O `flutter create` inclui `INTERNET` nos
  manifests de debug/profile; para **release** adiciona a
  `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```

- **Localização** (opcional, para "A minha localização" e "Paragens próximas"):
  ```xml
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  ```
  A app funciona sem permissão — o mapa abre centrado no Barreiro.

## Ativar o tempo real (posições dos autocarros)

A app tem uma camada genérica `JsonVehiclesSource` que lê uma lista de veículos de um
endpoint JSON e mapeia os campos. Precisas só do **URL** que devolve as posições.

### Como descobrir o URL (2 minutos)

1. No **Chrome** (desktop), abre o mapa em direto da TCB:
   `https://tcbarreiro.pt/em-tempo-real/mapa-em-direto/`.
2. Prime `F12` (DevTools) → separador **Network**.
3. Filtra por `Fetch/XHR` e vê os pedidos que são feitos enquanto o mapa carrega.
4. Procura o pedido que devolve as posições (normalmente JSON com `lat`/`lon` ou `latitude`/`longitude`
   e um id de veículo). Copia o **Request URL**.
5. Na app, vai a **Definições → Tempo real**, cola o URL, ativa o interruptor e guarda.

### Mapeamento de campos

A app assume, por omissão, que cada item tem: `id`, `lat`, `lon`, `route_id`,
`route_short_name`, `headsign`, `bearing`, `speed`, `trip_id`, `timestamp`.

Se o JSON for diferente, podes:
- indicar o **caminho até à lista** (ex.: `data, vehicles` se a lista estiver em
  `{"data":{"vehicles":[...]}}`), e/ou
- editar os nomes dos campos em `lib/services/realtime_source.dart` (`JsonVehiclesConfig`).

> Nota: usar o backend privado da TCB pode violar os termos de uso do serviço e é frágil
> (pode mudar sem aviso). Usa com essa noção. Se a TCB vier a publicar GTFS-RT, a arquitetura
> está preparada para trocar a fonte sem tocar na UI.

## Estrutura

```
lib/
  main.dart                 # entrada
  app.dart                  # MaterialApp + tema
  theme/app_theme.dart      # design system (claro/escuro)
  models/
    gtfs_models.dart        # Stop, Route, Trip, StopTime, ServiceCalendar, GtfsFeed
    vehicle.dart            # LiveVehicle
  services/
    csv.dart                # parser CSV (RFC 4180)
    gtfs_parser.dart        # ZIP GTFS → GtfsFeed
    gtfs_repository.dart    # download + cache
    departure_engine.dart   # próximas passagens
    realtime_source.dart    # abstração de tempo real (JSON)
    location_service.dart   # GPS + distâncias
    settings_store.dart     # preferências persistidas
  state/app_state.dart      # estado global (provider)
  screens/                  # mapa, paragens, carreiras, detalhes, definições
  widgets/                  # marcadores, badges, tiles, estados vazios
```

## Troubleshooting

- **`flutter pub get` falha a resolver versões**: atualiza as versões em `pubspec.yaml`
  (a app usa `flutter_map ^7`, `geolocator ^12`, etc.). Corre `flutter pub outdated`.
- **Mapa em branco**: verifica a ligação à internet e a permissão `INTERNET`.
- **Sem localização**: verifica as permissões de localização do Android e que o GPS está ligado.
