# Privacy Defaults

SKITTLES makes targeted privacy choices that preserve an ordinary desktop/networking experience. None of these settings create anonymity, and several intentionally trade persistence for compatibility.

| Setting | Default | Purpose | Compatibility impact | Override | Doctor verification |
| --- | --- | --- | --- | --- | --- |
| DHCP hostname | IPv4/IPv6 sending off | Avoid broadcasting the local hostname to DHCP infrastructure | Some networks may prefer/require a hostname | Override `ipv4.dhcp-send-hostname` / `ipv6.dhcp-send-hostname` in a specific connection | Checks both global defaults |
| DHCPv4 client ID / IAID | `stable` / `stable` | Avoid direct hardware-derived identity while keeping a repeatable lease identity | Same profile can remain linkable over time | Set per connection with `nmcli` | Checks global defaults |
| DHCPv6 DUID / IAID | `stable-uuid` / `stable` | Stable pseudonymous IPv6 DHCP identity | Same profile can remain linkable over time | Set per connection | Checks global defaults |
| Wi-Fi scan MAC | randomized | Reduce passive probe/scan tracking | Rare drivers/AP workflows may behave differently | Change NetworkManager device default | Checks `wifi.scan-rand-mac-address=yes` |
| Wi-Fi connection MAC | `stable-ssid` | Avoid exposing permanent MAC across networks while keeping one stable address per SSID | Captive portals/MAC allowlists may need adjustment; same SSID remains linkable | Set `802-11-wireless.cloned-mac-address` per profile | Checks global cloned-MAC default |
| IPv6 address generation | `stable-privacy`, temporary addresses preferred | Avoid embedding stable hardware identifiers and prefer temporary addresses for outbound use | Some services relying on a fixed client IPv6 address need explicit configuration | Override per connection | Checks both defaults |
| LLMNR | off in NetworkManager and resolved | Reduce local-name broadcast/responder exposure | `.local`/LAN discovery workflows may need DNS or explicit override | Enable only on chosen profile/link | Checks both layers |
| mDNS | off in NetworkManager and resolved | Reduce multicast service/name discovery | Printers/casting/service discovery may need explicit enablement | Enable only where needed | Checks both layers |
| Resolver mode | NetworkManager → `systemd-resolved` stub | Keep one coherent DNS owner and inspectable resolver state | Applications still use normal libc resolver path | Change NetworkManager DNS mode and `/etc/resolv.conf` deliberately | Checks config, symlink, `resolvectl status` |
| DNS-over-TLS | off | Avoid pretending encrypted DNS works without an explicit trusted-resolver policy | DNS is visible to the configured resolver/network path | Configure trusted resolvers and `DNSOverTLS=` yourself | Checks `DNSOverTLS=no` |
| Fallback DNS | empty / disabled | Use DNS learned from the active network without silently switching to systemd's compiled-in public resolvers | Name resolution fails when an active link supplies no working DNS | Configure `FallbackDNS=` explicitly if that tradeoff is desired | Checks the empty `FallbackDNS=` assignment |
| NetworkManager connectivity check | off | Avoid periodic distribution connectivity-probe requests | Captive portals are not auto-detected | Re-enable NetworkManager connectivity checking | Checks `enabled=false` |
| Journal | persistent, max 256 MiB, max 14 days | Keep enough diagnostic history without indefinite retention | Older logs are removed; disk usage bounded | Edit journald drop-in | Checks configured caps |
| Baloo | content indexing off for created user | Avoid background content indexing and index metadata | KDE search/content discovery is reduced | Re-enable in KDE/Baloo config | Checks user config when run unprivileged |
| Crash dumps | `Storage=none`, `ProcessSizeMax=0` | Avoid retaining process memory in coredump storage | Less post-crash forensic detail | Change coredump drop-in knowingly | Doctor checks both settings |
| nftables | inbound/forward drop, outbound accept | Reduce unsolicited network exposure | Hosting, VM bridges, Docker, hotspots, LAN sharing need deliberate rules | Edit and validate `/etc/nftables.conf` | Root doctor checks ruleset and policies |
| LUKS discard | off unless `--allow-discards` | Avoid revealing free-space patterns by default | SSD unused-block reclamation through encrypted root is disabled | Reinstall choice is recorded; advanced users can change crypttab/cmdline + fstrim deliberately | Doctor compares release record, timer, and live mapper |

## Network identity details

The defaults reduce use of a permanent Wi-Fi MAC and suppress DHCP hostname announcements. They do not make each connection unlinkable: stable NetworkManager identifiers and the stable-per-SSID association MAC are intentionally persistent for compatibility.

Wired Ethernet MAC cloning is not globally forced. Networks can still observe the physical Ethernet MAC unless the user configures a connection-specific cloned address.

## DNS

SKITTLES uses `systemd-resolved` as the local resolver and points `/etc/resolv.conf` to its stub. DNS is network-provided through the active connection. `FallbackDNS=` is deliberately empty, so SKITTLES does not silently substitute Google, Cloudflare, Quad9, or systemd's compiled-in public fallback list when a link provides no usable DNS. `DNSOverTLS=no` is explicit: SKITTLES does not provide encrypted DNS and makes no such privacy claim.

A VPN, encrypted DNS provider, Tor, application-specific DNS, or other privacy network layer is outside SKITTLES' scope.

## Local data and logs

LUKS protects root data while the machine is powered off and locked. Once root is unlocked, ordinary privileged processes and malware with sufficient access can read data. Journal limits, private home permissions, Baloo defaults, and coredump settings reduce retained local metadata but cannot protect an already compromised session.

## Overrides

Connection-specific NetworkManager settings should normally be preferred over weakening global defaults. After changes, inspect the merged NetworkManager configuration with:

```bash
NetworkManager --print-config
nmcli connection show
resolvectl status
```

Then run `skittles-doctor` / `sudo skittles-doctor` and treat expected failures as documentation that you intentionally diverged from the SKITTLES baseline.
