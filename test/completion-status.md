# ably-dart Test Completion Status

This matrix lists all spec items from the [Ably features spec](../../specification/md/features.md) and indicates which have Dart tests in this repo. It also cross-references whether a UTS test spec exists.

**Legend:**
- **Yes** — Dart test exists covering this item
- **Partial** — some sub-items covered, others not
- *blank* — no Dart test exists
- **UTS** column indicates whether a UTS test spec exists to guide implementation

---

## Specification and Protocol Versions

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| CSV1–CSV2 | Specification & protocol versions | | |

## Client Library Endpoint Configuration

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| REC1 | Primary domain determination (REC1a–REC1d2) | Yes — `unit/client/fallback_test.dart` | Yes |
| REC2 | Fallback domains determination (REC2a–REC2c6) | Yes — `unit/client/fallback_test.dart` | Yes |
| REC3 | Connectivity check URL (REC3a–REC3b) | Yes — `unit/client/fallback_test.dart` | Yes |

---

## REST Client Library

### RestClient

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSC1 | Constructor options (RSC1a–RSC1c) | Yes — `unit/client/client_options_test.dart` | Yes |
| RSC2 | Logger default | | |
| RSC3 | Log level configuration | | |
| RSC4 | Custom logger | | |
| RSC5 | Auth object attribute | | |
| RSC6 | Stats function (RSC6a–RSC6b4) | | Yes |
| RSC7 | HTTP request headers (RSC7a–RSC7d7) | Yes — `unit/client/rest_client_test.dart` | Yes |
| RSC8 | Protocol support (RSC8a–RSC8e2) | Yes — `unit/client/rest_client_test.dart` | Yes |
| RSC9 | Auth usage for authentication | | |
| RSC10 | Token error retry handling | | |
| RSC13 | Connection and request timeouts | Yes — `unit/client/rest_client_test.dart` | Yes |
| RSC15 | Host fallback behaviour (RSC15a–RSC15n) | | Yes |
| RSC16 | Time function | Yes — `unit/client/time_test.dart` | Yes |
| RSC17 | ClientId attribute | | |
| RSC18 | TLS configuration | Yes — `unit/client/rest_client_test.dart`, `unit/client/time_test.dart` | Yes |
| RSC19 | Request function (RSC19a–RSC19f1) | Yes — `unit/client/request_test.dart` | Yes |
| RSC20 | Deprecated exception reporting (RSC20a–RSC20f) | | |
| RSC21 | Push object attribute | | |
| RSC22 | BatchPublish (RSC22a–RSC22d) | Yes — `unit/client/batch_publish_test.dart` | Yes |
| RSC23 | Deleted | | |
| RSC24 | BatchPresence | | |
| RSC25 | Request endpoint | | |
| RSC26 | CreateWrapperSDKProxy (RSC26a–RSC26c) | | |

### Auth

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSA1 | Basic Auth requires HTTPS | Yes — `unit/auth/auth_scheme_test.dart` | Yes |
| RSA2 | Basic Auth default | Yes — `unit/auth/auth_scheme_test.dart` | Yes |
| RSA3 | Token Auth support (RSA3a–RSA3d) | Yes — `unit/auth/auth_scheme_test.dart` | Yes |
| RSA4 | Token Auth selection logic (RSA4a–RSA4g) | Partial — `unit/auth/auth_scheme_test.dart` (RSA4a–RSA4c), `unit/auth/token_renewal_test.dart` (RSA4b4), `unit/realtime/auth/connection_auth_test.dart` (RSA4) | Partial |
| RSA5 | TTL for tokens | | |
| RSA6 | Capability JSON | | |
| RSA7 | ClientId and authenticated clients (RSA7a–RSA7e2) | Partial — `unit/auth/client_id_test.dart` (RSA7, RSA7a–RSA7c) | Partial |
| RSA8 | RequestToken function (RSA8a–RSA8g) | Partial — `unit/auth/auth_callback_test.dart` (RSA8c, RSA8d), `unit/realtime/auth/connection_auth_test.dart` (RSA8d) | Partial |
| RSA9 | CreateTokenRequest (RSA9a–RSA9i) | | Partial |
| RSA10 | Authorize function (RSA10a–RSA10l) | Yes — `unit/auth/authorize_test.dart` | Yes |
| RSA11 | Base64 encoded API key | | |
| RSA12 | Auth#clientId attribute (RSA12a–RSA12b) | Yes — `unit/auth/client_id_test.dart` | Yes |
| RSA14 | Error when token auth selected without token | Yes — `unit/auth/token_renewal_test.dart` | Yes |
| RSA15 | ClientId validation (RSA15a–RSA15c) | | |
| RSA16 | TokenDetails attribute (RSA16a–RSA16d) | Yes — `unit/auth/token_details_test.dart` | Yes |
| RSA17 | RevokeTokens (RSA17a–RSA17g) | | |

### Channels (REST)

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSN1–RSN4 | REST channels collection (RSN1–RSN4c) | | |

### RestChannel

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSL1 | Publish function (RSL1a–RSL1n1) | Yes — `unit/channel/publish_test.dart` | Yes |
| RSL1k | Idempotent publishing (RSL1k1–RSL1k5) | Yes — `unit/channel/idempotency_test.dart` | Yes |
| RSL2 | History function (RSL2a–RSL2b3) | Yes — `unit/channel/history_test.dart` | Yes |
| RSL3 | Presence attribute | | |
| RSL4 | Message encoding (RSL4a–RSL4d4) | Yes — `unit/encoding/message_encoding_test.dart` | Yes |
| RSL5 | Message encryption (RSL5a–RSL5c) | | |
| RSL6 | Message decoding (RSL6a–RSL6b) | Yes — `unit/encoding/message_encoding_test.dart` | Yes |
| RSL7 | SetOptions function | | |
| RSL8 | Status function (RSL8a) | | |
| RSL9 | Name attribute | | |
| RSL10 | Annotations attribute | | |
| RSL11 | GetMessage function (RSL11a–RSL11c) | | |
| RSL14 | GetMessageVersions (RSL14a–RSL14c) | | |
| RSL15 | UpdateMessage/DeleteMessage/AppendMessage (RSL15a–RSL15f) | | |

### Plugins

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| PC1–PC5 | Plugin architecture, VCDiff, Objects | | |
| PT1–PT2 | PluginType enum | | |
| VD1–VD2 | VCDiffDecoder | | |

### RestPresence

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSP1 | Associated with single channel | Yes — `unit/presence/rest_presence_test.dart` | Yes |
| RSP3 | Get function (RSP3a–RSP3a3) | Yes — `unit/presence/rest_presence_test.dart` | Yes |
| RSP4 | History function (RSP4a–RSP4b3) | Yes — `unit/presence/rest_presence_test.dart` | Yes |
| RSP5 | Presence message decoding | Yes — `unit/presence/rest_presence_test.dart` | Yes |

### Encryption

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSE1 | Crypto::getDefaultParams (RSE1a–RSE1e) | | |
| RSE2 | Crypto::generateRandomKey (RSE2a–RSE2b) | | |

### RestAnnotations

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSAN1–RSAN3 | Annotations publish/delete/get | | |

### Forwards Compatibility (REST)

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSF1 | Robustness principle | | |

---

## Realtime Client Library

### RealtimeClient

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTC1 | ClientOptions (RTC1a–RTC1f1) | Partial — `unit/realtime/realtime_client_test.dart` (RTC1a) | Yes |
| RTC2 | Connection object attribute | Yes — `unit/realtime/realtime_client_test.dart` | Yes |
| RTC3 | Channels object attribute | Yes — `unit/realtime/realtime_client_test.dart` | Yes |
| RTC4 | Auth object attribute (RTC4a) | Yes — `unit/realtime/realtime_client_test.dart` | Yes |
| RTC5 | Stats function (RTC5a–RTC5b) | | |
| RTC6 | Time function (RTC6a) | | |
| RTC7 | Uses configured timeouts | | |
| RTC8 | Authorize function for realtime (RTC8a–RTC8c) | | |
| RTC9 | Request function | | |
| RTC10–RTC11 | Deleted | | |
| RTC12 | Same constructors as RestClient | | Yes |
| RTC13 | Push object attribute | | |
| RTC14 | CreateWrapperSDKProxy (RTC14a–RTC14c) | | |
| RTC15 | Connect function (RTC15a) | Yes — `unit/realtime/realtime_client_test.dart` | Yes |
| RTC16 | Close function (RTC16a) | Yes — `unit/realtime/realtime_client_test.dart` | Yes |
| RTC17 | ClientId attribute (RTC17a) | Yes — `unit/realtime/realtime_client_test.dart` | Yes |

### Connection

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTN1 | Uses websocket connection | | |
| RTN2 | Default host and query string params (RTN2a–RTN2g) | Partial — `unit/realtime/auth/connection_auth_test.dart` (RTN2e) | Partial |
| RTN3 | AutoConnect option | | |
| RTN4 | Connection event emission (RTN4a–RTN4i) | Partial — `integration/realtime/connection_lifecycle_test.dart` (RTN4b, RTN4c) | Partial |
| RTN5 | Concurrency test (50+ clients) | | |
| RTN6 | Successful connection definition | | |
| RTN7 | ACK and NACK handling (RTN7a–RTN7e) | Partial — `unit/realtime/channels/channel_publish_test.dart` covers RTN7a, RTN7b (via RTL6j tests) | Partial |
| RTN8 | Connection#id attribute (RTN8a–RTN8c) | Yes — `unit/realtime/connection/connection_id_key_test.dart` | Yes |
| RTN9 | Connection#key attribute (RTN9a–RTN9c) | Yes — `unit/realtime/connection/connection_id_key_test.dart` | Yes |
| RTN11 | Connect function (RTN11a–RTN11f) | Partial — `integration/realtime/connection_lifecycle_test.dart` (RTN11, RTN11e) | Partial |
| RTN12 | Close function (RTN12a–RTN12f) | Partial — `integration/realtime/connection_lifecycle_test.dart` (RTN12, RTN12a) | Partial |
| RTN13 | Ping function (RTN13a–RTN13e) | Yes — `unit/realtime/connection/connection_ping_test.dart` | Yes |
| RTN14 | Connection opening failures (RTN14a–RTN14g) | Yes — `unit/realtime/connection/connection_open_failures_test.dart` | Yes |
| RTN15 | Connection failures when CONNECTED (RTN15a–RTN15j) | Yes — `unit/realtime/connection/connection_failures_test.dart` | Yes |
| RTN16 | Connection recovery (RTN16a–RTN16m1) | | Partial |
| RTN17 | Domain selection and fallback (RTN17a–RTN17j) | Yes — `unit/realtime/connection/fallback_hosts_test.dart` | Yes |
| RTN19 | Transport state side effects (RTN19a–RTN19b) | | |
| RTN20 | OS network change handling (RTN20a–RTN20c) | | |
| RTN21 | ConnectionDetails override defaults | Partial — `integration/realtime/connection_lifecycle_test.dart` (RTN21) | Partial |
| RTN22 | Re-authentication request handling (RTN22a) | | |
| RTN23 | Heartbeats (RTN23a–RTN23b) | Yes — `unit/realtime/connection/heartbeat_test.dart` | Yes |
| RTN24 | UPDATE event on CONNECTED while connected | Yes — `unit/realtime/connection/update_events_test.dart` | Yes |
| RTN25 | Connection#errorReason attribute | Yes — `unit/realtime/connection/error_reason_test.dart` | Yes |
| RTN26 | Connection#whenState function (RTN26a–RTN26b) | Yes — `unit/realtime/connection/when_state_test.dart` | Yes |
| RTN27 | Connection state machine (RTN27a–RTN27h) | Partial — `unit/realtime/auth/connection_auth_test.dart` (RTN27b) | Partial |

### Channels (Realtime)

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTS1 | Channels collection accessible via RealtimeClient | Yes — `unit/realtime/channels/channels_collection_test.dart` | Yes |
| RTS2 | Methods to check existence and iterate | Yes — `unit/realtime/channels/channels_collection_test.dart` | Yes |
| RTS3 | Get function (RTS3a–RTS3c1) | Yes — `channels_collection_test.dart` (RTS3a), `channel_options_test.dart` (RTS3b, RTS3c, RTS3c1) | Yes |
| RTS4 | Release function (RTS4a) | Yes — `unit/realtime/channels/channels_collection_test.dart` | Yes |
| RTS5 | GetDerived function (RTS5a–RTS5a2) | Yes — `unit/realtime/channels/channel_options_test.dart` | Yes |

### RealtimeChannel

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTL1 | Message and presence processing | | |
| RTL2 | Channel event emission (RTL2a–RTL2i) | Yes — `unit/realtime/channels/channel_state_events_test.dart` | Yes |
| RTL3 | Connection state side effects (RTL3a–RTL3e) | Yes — `unit/realtime/channels/channel_connection_state_test.dart` | Yes |
| RTL4 | Attach function (RTL4a–RTL4m) | Yes — `unit/realtime/channels/channel_attach_test.dart` | Yes |
| RTL5 | Detach function (RTL5a–RTL5l) | Yes — `unit/realtime/channels/channel_detach_test.dart` | Yes |
| RTL6 | Publish function (RTL6a–RTL6k) | Yes — `unit/realtime/channels/channel_publish_test.dart` | Yes |
| RTL7 | Subscribe function (RTL7a–RTL7h) | Yes — `unit/realtime/channels/channel_subscribe_test.dart` | Yes |
| RTL8 | Unsubscribe function (RTL8a–RTL8c) | Yes — `unit/realtime/channels/channel_subscribe_test.dart` | Yes |
| RTL9 | Presence attribute (RTL9a) | | |
| RTL10 | History function (RTL10a–RTL10d) | | |
| RTL11 | Channel state effect on presence (RTL11a) | | |
| RTL12 | Additional ATTACHED message handling | | |
| RTL13 | Server-initiated DETACHED handling (RTL13a–RTL13c) | Yes — `unit/realtime/channels/channel_server_initiated_detach_test.dart` | Yes |
| RTL14 | ERROR message handling | Yes — `unit/realtime/channels/channel_error_test.dart` | Yes |
| RTL15 | Channel#properties attribute (RTL15a–RTL15b1) | Yes — `unit/realtime/channels/channel_properties_test.dart` | Yes |
| RTL16 | SetOptions function (RTL16a) | Yes — `unit/realtime/channels/channel_options_test.dart` | Yes |
| RTL17 | No messages outside ATTACHED state | Yes — `unit/realtime/channels/channel_subscribe_test.dart` | Yes |
| RTL18 | Vcdiff decoding failure recovery (RTL18a–RTL18c) | | |
| RTL19 | Base payload storage for vcdiff (RTL19a–RTL19c) | | |
| RTL20 | Last message ID storage | | |
| RTL21 | Message ordering in arrays | | |
| RTL22 | Message filtering (RTL22a–RTL22d) | | |
| RTL23 | Name attribute | | |
| RTL24 | ErrorReason attribute | | |
| RTL25 | WhenState function (RTL25a–RTL25b) | | |
| RTL26 | Annotations attribute | | |
| RTL27 | Objects attribute (RTL27a–RTL27b) | | |
| RTL28 | GetMessage function | | |
| RTL31 | GetMessageVersions function | | |
| RTL32 | UpdateMessage/DeleteMessage/AppendMessage (RTL32a–RTL32e) | | |

### RealtimePresence

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTP1 | HAS_PRESENCE flag and SYNC | | |
| RTP2 | PresenceMap maintenance (RTP2a–RTP2h2) | | |
| RTP4 | Large member count test | | |
| RTP5 | Channel state side effects (RTP5a–RTP5f) | | |
| RTP6 | Subscribe function (RTP6a–RTP6e) | | |
| RTP7 | Unsubscribe function (RTP7a–RTP7c) | | |
| RTP8 | Enter function (RTP8a–RTP8j) | | |
| RTP9 | Update function (RTP9a–RTP9e) | | |
| RTP10 | Leave function (RTP10a–RTP10e) | | |
| RTP11 | Get function (RTP11a–RTP11d) | | |
| RTP12 | History function (RTP12a–RTP12d) | | |
| RTP13 | SyncComplete attribute | | |
| RTP14 | EnterClient function (RTP14a–RTP14d) | | |
| RTP15 | EnterClient/UpdateClient/LeaveClient (RTP15a–RTP15f) | | |
| RTP16 | Connection state conditions (RTP16a–RTP16c) | | |
| RTP17 | Internal PresenceMap (RTP17a–RTP17j) | | |
| RTP18 | Server-initiated sync (RTP18a–RTP18c) | | |
| RTP19 | PresenceMap cleanup on sync (RTP19a) | | |

### RealtimeAnnotations

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTAN1–RTAN5 | Annotations publish/delete/get/subscribe/unsubscribe | | |

### EventEmitter

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTE1–RTE6 | EventEmitter interface (on/once/off/emit) | | |

### Incremental Backoff and Jitter

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTB1 | Retry timeout calculation (RTB1a–RTB1b) | | |

### Forwards Compatibility (Realtime)

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RTF1 | Robustness principle | | |

### Wrapper SDK Proxy Client

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| WP1–WP7 | Wrapper SDK proxy client | | |

---

## Push Notifications

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| RSH1 | Push#admin object (RSH1a–RSH1c5) | | |
| RSH2 | Platform-specific push operations (RSH2a–RSH2e) | | |
| RSH3 | Activation state machine (RSH3a–RSH3g3) | | |
| RSH4–RSH5 | Event queueing and sequential handling | | |
| RSH6 | Push device authentication (RSH6a–RSH6b) | | |
| RSH7 | Push channels (RSH7a–RSH7e) | | |
| RSH8 | LocalDevice (RSH8a–RSH8k2) | | |

---

## Types

### Data Types

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| TM1–TM8 | Message (TM1–TM8a1) | Partial — `unit/types/message_types_test.dart` (TM1–TM5) | Partial |
| DE1–DE2 | DeltaExtras | | |
| TP1–TP5 | PresenceMessage | | |
| OM1–OM5 | ObjectMessage | | |
| OOP1–OOP5 | ObjectOperation | | |
| OST1–OST3 | ObjectState | | |
| OMO1–OMO3 | ObjectsMapOp | | |
| OCO1–OCO3 | ObjectsCounterOp | | |
| OMP1–OMP4 | ObjectsMap | | |
| OCN1–OCN3 | ObjectsCounter | | |
| OME1–OME3 | ObjectsMapEntry | | |
| OD1–OD5 | ObjectData | | |
| TAN1–TAN3 | Annotation | | |
| TR1–TR4 | ProtocolMessage | | |
| TG1–TG7 | PaginatedResult | Yes — `unit/types/paginated_result_test.dart` | Yes |
| HP1–HP8 | HttpPaginatedResponse | Yes — `unit/client/request_test.dart` | Yes |
| TE1–TE6 | TokenRequest | Yes — `unit/types/token_types_test.dart` | Yes |
| TD1–TD7 | TokenDetails | Yes — `unit/types/token_types_test.dart` | Yes |
| TN1–TN3 | Token string | | |
| AD1–AD2 | AuthDetails | | |
| TS1–TS14 | Stats | | |
| TI1–TI5 | ErrorInfo | Yes — `unit/types/error_types_test.dart` | Yes |
| TA1–TA5 | ConnectionStateChange | | |
| TH1–TH6 | ChannelStateChange | Yes — `unit/realtime/channels/channel_state_events_test.dart` | Yes |
| TC1–TC2 | Capability | | |
| CD1–CD2 | ConnectionDetails | | |
| CP1–CP2 | ChannelProperties | | |
| CHD1–CHD2, CHS1–CHS2, CHO1–CHO2, CHM1–CHM2 | Channel status types | | |
| BAR1–BAR2 | BatchResult | | |
| BSP1–BSP2 | BatchPublishSpec | | |
| BPR1–BPR2, BPF1–BPF2 | BatchPublish result types | | |
| BGR1–BGR2, BGF1–BGF2 | BatchPresence result types | | |
| PBR1–PBR2 | PublishResult | Yes — `unit/realtime/channels/channel_publish_test.dart` | Yes |
| UDR1–UDR2 | UpdateDeleteResult | | |
| TRT1–TRT2, TRS1–TRS2, TRF1–TRF2 | TokenRevocation types | | |
| MFI1–MFI2 | MessageFilter | | |
| REX1–REX2 | ReferenceExtras | | |

### Option Types

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| TO1–TO3 | ClientOptions | Yes — `unit/types/options_types_test.dart` | Yes |
| TK1–TK6 | TokenParams | Yes — `unit/types/token_types_test.dart` | Yes |
| AO1–AO2 | AuthOptions | Yes — `unit/types/options_types_test.dart` | Yes |
| TB1–TB4 | ChannelOptions | Yes — `unit/realtime/channels/channel_options_test.dart` | Yes |
| DO1–DO2 | DeriveOptions | Yes — `unit/realtime/channels/channel_options_test.dart` | Yes |
| TZ1–TZ2 | CipherParams | | |
| CO1–CO2 | CipherParamOptions | | |
| WPO1–WPO2 | WrapperSDKProxyOptions | | |

### Push Notification Types

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| PCS1–PCS5 | PushChannelSubscription | | |
| PCD1–PCD7 | DeviceDetails | | |
| PCP1–PCP4 | DevicePushDetails | | |

### Client Library Introspection

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| CR1–CR3 | ClientInformation | | |

### Client Library Defaults

| Spec item | Description | Dart test | UTS spec |
|-----------|-------------|-----------|----------|
| DF1 | Default values (DF1a–DF1b) | | |

---

## Summary

| Area | Spec groups | With Dart test | With UTS spec | Notes |
|------|-------------|----------------|---------------|-------|
| **Endpoint config** (REC) | 3 | 3 | 3 | Full |
| **REST client** (RSC) | 18 | 8 | 9 | Missing: RSC6 (stats), RSC15 (fallback) |
| **REST auth** (RSA) | 15 | 10 | 10 | Aligned with UTS |
| **REST channels** (RSN) | 4 | 0 | 0 | |
| **REST channel** (RSL) | 13 | 6 | 6 | Aligned with UTS |
| **REST presence** (RSP) | 5 | 4 | 4 | Aligned with UTS |
| **REST encryption** (RSE) | 2 | 0 | 0 | |
| **REST annotations** (RSAN) | 3 | 0 | 0 | |
| **Realtime client** (RTC) | 14 | 7 | 8 | Missing: RTC12 |
| **Connection** (RTN) | 23 | 14 | 16 | Missing: RTN16, RTN21 full coverage |
| **Realtime channels** (RTS) | 5 | 5 | 5 | Full |
| **Realtime channel** (RTL) | 24 | 14 | 14 | |
| **Realtime presence** (RTP) | 15 | 0 | 0 | |
| **Realtime annotations** (RTAN) | 5 | 0 | 0 | |
| **EventEmitter** (RTE) | 6 | 0 | 0 | |
| **Backoff/jitter** (RTB) | 1 | 0 | 0 | |
| **Wrapper SDK** (WP) | 7 | 0 | 0 | |
| **Push notifications** (RSH) | 8 | 0 | 0 | |
| **Plugins** (PC/PT/VD) | 3 | 0 | 0 | |
| **Data types** | 30 | 7 | 7 | Aligned with UTS |
| **Option types** | 8 | 5 | 5 | Aligned with UTS |
| **Push types** | 3 | 0 | 0 | |
| **Introspection** (CR) | 1 | 0 | 0 | |
| **Defaults** (DF) | 1 | 0 | 0 | |
| **Compatibility** (RSF/RTF) | 2 | 0 | 0 | |
