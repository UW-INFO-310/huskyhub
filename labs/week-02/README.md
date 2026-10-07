# Week 2 Lab — Networking, Packet Capture, and Man-in-the-Middle

**Quarter:** Autumn 2026 · **Lecture:** Networking, OSI Model, and MITM Attacks

**Prerequisites:** Week 1; the starter still uses HTTP. Do not add HTTPS or signed sessions yet.

[Course index](../../README.md) · [Setup help](../../TROUBLESHOOTING.md) · [Report requirements](../../LAB_GUIDE.md)

## Overview

First capture your own login to see credentials and identity cookies in cleartext. Then position an attacker between a separate browser client and the HuskyHub server using targeted ARP spoofing. Replay the captured identity cookies, restore the network, and explain the security failure. No remediation this week: HTTPS is Week 3, signed sessions are Week 5.

## Network Scope

Use only an isolated network with consent from the owners of every participating device. Do not run the ARP exercise on campus, apartment, office, public, or other shared networks. The scripts alter the selected peers' IP-to-MAC mappings and can disrupt traffic. Keep a record of original forwarding settings and restore them afterwards.

Your own localhost packet capture does not require ARP spoofing. Do not confuse seeing traffic sent directly to your server with demonstrating interception by a third endpoint.

## Tools and Setup

| Tool | Purpose |
|---|---|
| Wireshark | Capture and inspect packets |
| Scapy | Send the provided ARP demonstration packets |
| Terminal | Run helpers and inspect network state |
| Browser Developer Tools | Inspect/replay identity cookies |

Install [Wireshark](https://www.wireshark.org/download.html) for your platform. Windows needs Npcap, including loopback capture support. macOS may need its ChmodBPF capture-permissions helper. Install Python/Scapy in a local environment; see [setup help](../../TROUBLESHOOTING.md#python-tools).

The provided arpspoof.py sends **one direction per invocation**:

```text
arpspoof.py <interface> <target-ip> <claimed-ip>
arprestore.py <interface> <target-ip> <real-ip>
```

Run two spoof processes for the two directions; restore each direction once after stopping both. These helpers do **not** forward IP packets. Configure forwarding separately in Step 7.

## Steps

### 1. Identify Interfaces

Find your active network interface and IP:

```bash
# macOS
ifconfig
route get default
# Linux
ip addr
ip route
```

On Windows use `ipconfig` and `Get-NetAdapter` in PowerShell. Record the active interface's name and IP. Do not assume en0, a particular subnet, or a phone hotspot's address range.

### 2. Start a Localhost Capture

Open Wireshark and choose the **loopback** interface: macOS lo0, Linux lo, or Windows Npcap Loopback Adapter. Start capture before logging in. Wi-Fi is for the later network exercise; it does not carry your browser's localhost traffic.

Wireshark's packet list shows individual packets; the detail pane expands protocol layers. A display filter narrows what is shown without changing what was captured.

### 3. Log In Locally

With capture running, open `http://localhost/login` and log in as `jsmith`. Visit another page so a request carries the newly issued cookies. Stop capture.

### 4. Find Cleartext Credentials

Use display filter `http.request.method == "POST"`. Select the login request, expand HTTP and HTML Form URL Encoded, and screenshot the username/password fields. Explain where this data sits in the request. If no POST appears, confirm capture started first and used loopback.

### 5. Find Identity Cookies

Use `http.cookie`. Record the full authenticated, role, and user_id values in a captured request. These are unsigned identity claims in this starter, not opaque server-side session IDs. Explain why possessing all three is enough to impersonate the fixture user without a password.

### 6. Prepare a Real Client–Server–Attacker Path

The MITM exercise needs **three distinct endpoints** on the same isolated IPv4 LAN:

| Role | Runs | Example |
|---|---|---|
| Server | HuskyHub Docker stack | Partner's laptop |
| Client (victim) | Browser visiting the server's LAN IP | Phone or another laptop |
| Attacker | Wireshark and Scapy helpers | Your laptop |

Two laptops plus a browser-capable phone can provide all three roles. Alternatively use the teaching team's isolated lab setup. Confirm this arrangement with the teaching team before lab if you lack a third endpoint. Swap roles so everyone obtains the required observations.

On the server start the **Week 2 HTTP** application. On the client visit `http://<server-ip>/login` and log in as `alee`. Do not use localhost on the client: that addresses the client itself. The attacker must be distinct from the server; the original direct client→server path should not already terminate on the attacker.

Record all three IPs and the attacker's network interface. Verify the client can reach the server **before** spoofing. Host firewalls may require an exception for HTTP from the isolated LAN; do not turn off a firewall globally. A hotspot/router with client isolation cannot support this peer-to-peer exercise; use a teaching-team approved network instead.

On the attacker use `arp -a` (Windows/macOS) or `ip neigh` (Linux) to inspect neighbor mappings. The helper also resolves target MACs on the interface you specify. You will impersonate the **server to the client**, and the **client to the server**. The gateway need not be spoofed: these two peers talk directly on their LAN.

### 7. Configure Forwarding

Record the original settings before changing them. Forwarding makes the attacker pass intercepted traffic to its actual destination instead of dropping it; Scapy's ARP helpers do not do this themselves.

**macOS (attacker):**

```bash
sysctl net.inet.ip.forwarding net.inet.ip.redirect
sudo sysctl -w net.inet.ip.forwarding=1
sudo sysctl -w net.inet.ip.redirect=0
```

**Linux (attacker):**

```bash
sysctl net.ipv4.ip_forward net.ipv4.conf.all.send_redirects
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.send_redirects=0
```

Also record and temporarily disable send_redirects for the selected interface (for example `net.ipv4.conf.wlan0.send_redirects`), restoring that value afterwards. Kernel/firewall policies may still restrict same-interface forwarding; use the teaching team's tested lab host if traffic stops.

**Windows (PowerShell as Administrator, attacker):**

```powershell
Get-NetIPInterface -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 | Select-Object InterfaceAlias,Forwarding
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -Forwarding Enabled -PolicyStore ActiveStore
```

Replace Wi-Fi with the adapter actually used. [Microsoft documents this per-interface setting](https://learn.microsoft.com/en-us/powershell/module/nettcpip/set-netipinterface). Scapy still does not supply forwarding. If Windows routing/firewall policy prevents the required path, use an instructor-provided tested attacker host; do not claim success from poisoned ARP entries alone.

### 8. Execute the ARP Demonstration

Open two attacker terminals. On macOS/Linux:

```bash
# Terminal 1: client believes the server is at the attacker's MAC
sudo .venv/bin/python labs/week-02/scripts/arpspoof.py <interface> <client-ip> <server-ip>

# Terminal 2: server believes the client is at the attacker's MAC
sudo .venv/bin/python labs/week-02/scripts/arpspoof.py <interface> <server-ip> <client-ip>
```

On Windows use two Administrator PowerShell windows, `python` instead of `sudo .venv/bin/python`, and the same argument order. Quote the Scapy interface identifier if it contains spaces. Npcap/Scapy may display a device identifier instead of the friendly Windows alias; list Scapy interfaces with `python -c "from scapy.all import show_interfaces; show_interfaces()"` and select the matching adapter.

Inspect the client/server ARP entries before and during spoofing. Show that the peer's IP now resolves to the attacker MAC. The script's two-second interval keeps the selected mapping poisoned while the process runs.

### 9. Capture Intercepted Cookies

On the attacker, capture the **LAN interface**, not loopback. Apply `ip.addr == <client-ip> && http.cookie`. On the client, reload pages on `http://<server-ip>` while both spoof processes run.

Capture the three identity-cookie values and demonstrate that the client continues to receive normal responses. Record source/destination IPs and the relevant Ethernet MACs to show the changed path. If the client loses access, stop and restore immediately; an outage alone does not satisfy the interception exercise.

### 10. Replay the Victim's Identity

In the attacker's browser open the **same server** at `http://<server-ip>`. Use Developer Tools to set authenticated, role, and user_id for that host to the captured values. Do not mix localhost cookies with server-IP cookies. Reload `/grades` and document that you see the client's fixture identity without its password.

This exercises theft/replay of identity cookies. Manually inventing admin values without capturing traffic would instead repeat Week 5's forgery exercise.

### 11. Restore the Network

Stop **both** spoof processes with Ctrl+C. Restore each peer's genuine mapping:

```bash
sudo .venv/bin/python labs/week-02/scripts/arprestore.py <interface> <client-ip> <server-ip>
sudo .venv/bin/python labs/week-02/scripts/arprestore.py <interface> <server-ip> <client-ip>
```

Windows again uses Administrator PowerShell and `python` without sudo. Restore the forwarding/redirect settings you recorded in Step 7. For example, if the original forwarding value was 0, set it back to 0; do not disable a previously enabled configuration indiscriminately. On Windows restore the original Forwarding value with Set-NetIPInterface and ActiveStore.

Confirm the client/server ARP mappings and ordinary connectivity recover. Remove the replayed cookies, log out, and remove any temporary firewall rule you added for the exercise.

## Write-Up Questions

**Q1.** How did the captured identity cookies permit impersonation without the password? Distinguish login authentication, cookie integrity, and replay.

**Q2.** Relate ARP to the OSI model and explain how HTTPS protects the HTTP contents carried over the manipulated path. What remains observable, and what does encryption alone not fix?

**Q3.** What attacker placement was required? Why would localhost traffic or requests sent directly to the attacker fail to demonstrate this MITM path?

## Hacker Mindset Prompt

- **Contrarian:** What assumption about the network made cleartext credentials and cookies unsafe?
- **Committed:** What could an attacker do after replaying a valid identity? Keep examples within this lab's authorized scope.
- **Creative:** How could you verify a network defense using both path evidence and application observations, instead of assuming lack of packets means success?

## Submission Checklist

Submit the [four-section report](../../LAB_GUIDE.md), local credential/cookie captures, a labeled three-endpoint topology, before/during/after ARP evidence, intercepted-cookie/replay proof, and cleanup verification. Include platform-specific problems honestly. The teaching team must confirm device availability and its tested forwarding setup; due date, points, and LMS destination are **TBD by the instructor**.
