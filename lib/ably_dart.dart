/// Ably SDK for Dart.
///
/// This library provides a pure Dart implementation of the Ably REST and Realtime APIs.
library ably_dart;

// Authentication
export 'src/auth/auth.dart';
export 'src/auth/auth_options.dart';
export 'src/auth/client_options.dart';
export 'src/auth/token_details.dart';
export 'src/auth/token_params.dart';
export 'src/auth/token_request.dart';

// REST
export 'src/rest/rest.dart';

// Realtime
export 'src/realtime/realtime.dart';
export 'src/realtime/connection.dart';
export 'src/realtime/connection_state.dart';
export 'src/realtime/connection_event.dart';
export 'src/realtime/connection_state_change.dart';
export 'src/realtime/realtime_channels.dart';
export 'src/realtime/realtime_channel.dart';
export 'src/realtime/channel_state.dart';
export 'src/realtime/channel_event.dart';
export 'src/realtime/channel_state_change.dart';
export 'src/realtime/protocol_message.dart';

// Channels
export 'src/channels/channels.dart';
export 'src/channels/rest_channel.dart';
export 'src/channels/rest_channel_options.dart';
export 'src/channels/rest_history_params.dart';

// Presence
export 'src/presence/rest_presence.dart';
export 'src/presence/rest_presence_params.dart';
export 'src/presence/presence_action.dart';

// Messages
export 'src/message/message.dart';
export 'src/message/presence_message.dart';
export 'src/message/message_extras.dart';
export 'src/message/delta_extras.dart';

// Batch operations
export 'src/batch/batch_publish_spec.dart';
export 'src/batch/batch_result.dart';

// Pagination
export 'src/pagination/paginated_result.dart';
export 'src/pagination/http_paginated_response.dart';

// Errors
export 'src/error/error_info.dart';
export 'src/error/ably_exception.dart';
export 'src/error/error_codes.dart';

// Crypto
export 'src/crypto/crypto.dart';
export 'src/crypto/cipher_params.dart';

// Logging
export 'src/logging/log_level.dart';
export 'src/logging/log_handler.dart';
