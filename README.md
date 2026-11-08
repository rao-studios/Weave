[![Weave, by Rao Studios: spawn AIIs, and search every Thread as one. On a warm black plate, the title Weave in silver italic; beneath it a query leaves Weave's port, 47600, along a woven line to the host, a vermilion ring, and fans out into three coloured threads ending at three Threads, alpha on 47611, beta on 47621 and gamma on 47631. The legend reads: host, a Sewn; alpha, beta, gamma, Threads; one query, every partition, merged by score.](Docs/README_Assets/hero.png)](Docs/README_Assets/hero.png)

# Weave

Spawn AIIs on demand, and search every Thread as one.

Weave is a macOS app in the Rao Studios line. It spawns AIIs, each a full Ambient Intelligence Index home with its own Thread on its own ports. Each one takes deposits directly, embeds them on device with voyage-4-nano, and extracts their graph on device with Granite 4.0 H-Micro. The models already downloaded in `~/.rao` are shared, so a spawned AII downloads nothing.

Choose one AII as the host: the main AII in `~/.rao`, or one Weave spawned. Every woven Thread registers with the host's Sewn, and one query to the host fans out to all of them and merges their partitions by score. That is federated retrieval across data partitions, in its plainest form. Weave also opens a port of its own, so any local process can ask that question too.

## How it fits the Ambient Intelligence Index

| | HTTP | gRPC | What it is |
| --- | --- | --- | --- |
| Main AII Sewn | 47080 | 47091 | The Sewn every Rao app shares (`~/.rao`) |
| Main AII Thread | 47081 | 47090 | The index every Rao app shares |
| Weave | 47600 | | Weave's own port: `/health`, `/v1/threads`, `/v1/search` |
| Spawned AII *n* | 47600 + 10*n* + 1 | + 2 | Its Thread |
| Spawned AII *n*, as host | + 3 | + 4 | Its Sewn, started only while it hosts |

Each spawned AII lives in its own folder under the fabric's folder, `~/.rao/weave` by default. Any folder on an APFS volume works. Weave runs the AII build installed at `~/.rao/aii/bin/AIIServer` and never builds one.

**The fabric.** Weave registers itself in the main AII as the `weave` app. A spawned home is seeded before AII provisions it: its stack secret is Weave's secret in `~/.rao`, and its device key is a copy of the main one, so its lane ids match the main AII's. When the main AII hosts, the main Sewn sees Weave's Threads as Weave's nodes. Ambient, Craft and Veil never search or file into those nodes. When a spawned AII hosts, every peer registers with it as that home's own stack.

**The owner.** A deposit reaches a federated search only when it is filed as `local-weave`, the owner Weave's lane answers for. Weave's deposit pane always files that way, and `/v1/threads` says so.

## Build and run

Requirements: macOS 26 on Apple silicon, Swift 6.2 or later, and an installed AII build that grants `POST /v1/search` to a local app with no account. That grant is one line in the AII repository's `Sources/Sewn/API/Middleware/LocalOnlyGrant.swift`. Install it from the checkout:

```sh
aii install ~/Documents/rao/repositories/AII && aii restart
```

Then:

```sh
swift build                       # the app and WeaveKit
swift test                        # Ops, seeding on scratch AII homes, the port, the services
./scripts/dev/dev.sh              # build, stable-sign and run
./scripts/dev/dev.sh --self-test  # headless: a scratch AII home, a spawn, the port; exits 0/1
./scripts/build/make-app.sh       # build/Weave.app, icon compiled, signed
```

`Weave --e2e <folder>` runs the whole fabric against this Mac's real AII, then removes what it made. It spawns two AIIs, deposits into each, searches through the main AII and through Weave's port, makes one AII the host, and searches again.

## Using it

- **Spawn.** ⌘N names an AII and picks how it reads a graph: on device, or keywords only. Weave finds a free port slot, provisions the home, links the models, and starts its Thread woven into the host.
- **Weave in, weave out.** A woven Thread registers with the host. A loose one runs standalone and only takes direct deposits. Switching restarts the Thread, since a Thread reads its mothership at launch.
- **The host.** Choose it on the Fabric page. Weave brings the host's Sewn up and moves every running woven Thread onto it. The main AII is held with a lease, as every Rao app holds it.
- **Explore.** Any Thread, in Weave's lane: its counts and models, its library, its graph, a search of it alone, a deposit into it, and its log.
- **Search.** One query to the host. Each merged hit is named by the AII whose Thread answered it.
- **Quit.** Weave's port closes and its lease goes. Spawned Threads keep running and are adopted at the next launch, unless Settings say to stop them.

## Weave's port

```sh
curl -s 127.0.0.1:47600/health

curl -s 127.0.0.1:47600/v1/threads -H "X-Ambient-Secret: $(cat ~/.rao/secrets/weave)"

curl -s -X POST 127.0.0.1:47600/v1/search \
  -H "X-Ambient-Secret: $(cat ~/.rao/secrets/weave)" \
  -H 'Content-Type: application/json' \
  -d '{"query": "who reads punched cards?", "top_k": 10}'
```

The port binds 127.0.0.1 and refuses a request whose Host is not this Mac. `/v1/*` wants Weave's secret unless Settings turn that off.

A deposit goes straight to a spawned Thread, with that home's own `weave` secret:

```sh
curl -s -X POST 127.0.0.1:47611/v1/batch/embeddings \
  -H "X-Ambient-Secret: $(cat ~/.rao/weave/alpha/secrets/weave)" \
  -H 'Content-Type: application/json' \
  -d '{"inputs": ["The Jacquard loom reads punched cards."], "sanitize": true,
       "thread": {"owner_id": "local-weave", "group": {"id": "weave-alpha", "label": "Weave · alpha", "owner_id": "local-weave"}}}'
```

## Layout

Weave is built on [Granite](https://github.com/riteshpakala/Granite). Each subsystem is a service with one synchronous writer. Work runs in reducer effects, and replies come back as tickets. Each page is a component.

| Target | What it holds |
| --- | --- |
| `WeaveKit` | The services, the fabric's homes, ports and launch specs over AII's contract, the loopback clients for Thread and Sewn, and Weave's port (Hummingbird) |
| `Weave` | The app: the shell and settings services, the pages, the design, and `WeaveAppRoot`, the façade AppKit calls |

| Service | Responsible for |
| --- | --- |
| `FabricService` | The spawned homes and their Thread processes: scan, spawn, start, stop, weave, remove, and the probe loop |
| `HostService` | The host's Sewn: bringing it up, re-weaving the Threads onto it, and the nodes it sees |
| `SearchService` | The federated query, each hit named by instance |
| `PortService` | Weave's own port on 127.0.0.1 |
| `ExplorerService` | One Thread's stats, library, graph, search, deposits and log |
| `SettingsService`, `ShellService` | The app's preferences (`weave.settings.0001`) and its window |

The relays point down only: Search → Host → Fabric, Port → Host and Fabric, Explorer → Fabric.

## Scripts

| Script | Does |
| --- | --- |
| `scripts/dev/dev.sh` | Build, stable-sign and run |
| `scripts/build/make-app.sh [--install]` | Assemble, stamp and sign `build/Weave.app` |
| `scripts/art/gen-app-icon.swift` | Render the app icon from its SVG |
| `Docs/README_Assets/src/build.sh` | Rebuild this README's hero |

GNU General Public License v3.0 (see [LICENSE](LICENSE)).

> *Every thread its own; one cloth when you ask.*
