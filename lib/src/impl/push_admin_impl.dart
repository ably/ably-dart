import '../error/ably_exception.dart';
import '../error/error_info.dart';
import '../logging/logger.dart';
import '../pagination/paginated_result.dart';
import '../push/device_details.dart';
import '../push/push.dart';
import '../push/push_admin.dart';
import '../push/push_channel_subscription.dart';
import '../push/push_channel_subscriptions.dart';
import '../push/push_device_registrations.dart';
import 'http/http_client.dart';
import 'paginated_result_impl.dart';

/// Implementation of Push.
///
/// Spec: RSH1
class PushImpl implements Push {
  PushImpl({
    required AblyHttpClient httpClient,
    required Logger logger,
  }) : _admin = PushAdminImpl(httpClient: httpClient, logger: logger);

  final PushAdminImpl _admin;

  @override
  PushAdmin get admin => _admin;
}

/// Implementation of PushAdmin.
///
/// Spec: RSH1a–RSH1c
class PushAdminImpl implements PushAdmin {
  PushAdminImpl({
    required AblyHttpClient httpClient,
    required Logger logger,
  })  : _httpClient = httpClient,
        _logger = logger;

  final AblyHttpClient _httpClient;
  final Logger _logger;

  late final PushDeviceRegistrationsImpl _deviceRegistrations =
      PushDeviceRegistrationsImpl(httpClient: _httpClient, logger: _logger);

  late final PushChannelSubscriptionsImpl _channelSubscriptions =
      PushChannelSubscriptionsImpl(httpClient: _httpClient, logger: _logger);

  @override
  PushDeviceRegistrations get deviceRegistrations => _deviceRegistrations;

  @override
  PushChannelSubscriptions get channelSubscriptions => _channelSubscriptions;

  @override
  Future<void> publish(
    Map<String, dynamic> recipient,
    Map<String, dynamic> data,
  ) async {
    _logger.info('push.admin.publish() called', {});

    // RSH1a: Reject empty recipient
    if (recipient.isEmpty) {
      throw const AblyException(
        message: 'Recipient must not be empty',
        errorInfo: ErrorInfo(
          message: 'Recipient must not be empty',
          code: 40000,
          statusCode: 400,
        ),
      );
    }

    // RSH1a: Reject empty data
    if (data.isEmpty) {
      throw const AblyException(
        message: 'Data must not be empty',
        errorInfo: ErrorInfo(
          message: 'Data must not be empty',
          code: 40000,
          statusCode: 400,
        ),
      );
    }

    final body = <String, dynamic>{
      'recipient': recipient,
      ...data,
    };

    await _httpClient.request('POST', '/push/publish', body: body);
  }
}

/// Implementation of PushDeviceRegistrations.
///
/// Spec: RSH1b1–RSH1b5
class PushDeviceRegistrationsImpl implements PushDeviceRegistrations {
  PushDeviceRegistrationsImpl({
    required AblyHttpClient httpClient,
    required Logger logger,
  })  : _httpClient = httpClient,
        _logger = logger;

  final AblyHttpClient _httpClient;
  final Logger _logger;

  @override
  Future<DeviceDetails> get(String deviceId) async {
    _logger.info('push.admin.deviceRegistrations.get() called', {
      'deviceId': deviceId,
    });

    final path = '/push/deviceRegistrations/${Uri.encodeComponent(deviceId)}';
    final response = await _httpClient.request('GET', path);
    return DeviceDetails.fromMap(response.body as Map<String, dynamic>);
  }

  @override
  Future<PaginatedResult<DeviceDetails>> list(
    Map<String, String> params,
  ) async {
    _logger.info('push.admin.deviceRegistrations.list() called', {});

    final response = await _httpClient.request(
      'GET',
      '/push/deviceRegistrations',
      queryParams: params.isNotEmpty ? params : null,
    );

    final items = PaginatedResultParser.parseDeviceDetails(response.body);

    return PaginatedResultImpl.fromResponse<DeviceDetails>(
      response: response,
      items: items,
      fetcher: _fetchDeviceDetailsPage,
      requestPath: '/push/deviceRegistrations',
    );
  }

  Future<PaginatedResult<DeviceDetails>> _fetchDeviceDetailsPage(
    String url,
  ) async {
    final uri = Uri.parse(url);
    final path = uri.path;
    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );
    final items = PaginatedResultParser.parseDeviceDetails(response.body);
    return PaginatedResultImpl.fromResponse<DeviceDetails>(
      response: response,
      items: items,
      fetcher: _fetchDeviceDetailsPage,
      requestPath: path,
    );
  }

  @override
  Future<DeviceDetails> save(DeviceDetails device) async {
    _logger.info('push.admin.deviceRegistrations.save() called', {
      'deviceId': device.id,
    });

    final path = '/push/deviceRegistrations/${Uri.encodeComponent(device.id)}';
    final response = await _httpClient.request(
      'PUT',
      path,
      body: device.toMap(),
    );
    return DeviceDetails.fromMap(response.body as Map<String, dynamic>);
  }

  @override
  Future<void> remove(String deviceId) async {
    _logger.info('push.admin.deviceRegistrations.remove() called', {
      'deviceId': deviceId,
    });

    final path = '/push/deviceRegistrations/${Uri.encodeComponent(deviceId)}';
    await _httpClient.request('DELETE', path);
  }

  @override
  Future<void> removeWhere(Map<String, String> params) async {
    _logger.info('push.admin.deviceRegistrations.removeWhere() called', {});

    await _httpClient.request(
      'DELETE',
      '/push/deviceRegistrations',
      queryParams: params.isNotEmpty ? params : null,
    );
  }
}

/// Implementation of PushChannelSubscriptions.
///
/// Spec: RSH1c1–RSH1c5
class PushChannelSubscriptionsImpl implements PushChannelSubscriptions {
  PushChannelSubscriptionsImpl({
    required AblyHttpClient httpClient,
    required Logger logger,
  })  : _httpClient = httpClient,
        _logger = logger;

  final AblyHttpClient _httpClient;
  final Logger _logger;

  @override
  Future<PaginatedResult<PushChannelSubscription>> list(
    Map<String, String> params,
  ) async {
    _logger.info('push.admin.channelSubscriptions.list() called', {});

    final response = await _httpClient.request(
      'GET',
      '/push/channelSubscriptions',
      queryParams: params.isNotEmpty ? params : null,
    );

    final items =
        PaginatedResultParser.parsePushChannelSubscriptions(response.body);

    return PaginatedResultImpl.fromResponse<PushChannelSubscription>(
      response: response,
      items: items,
      fetcher: _fetchSubscriptionsPage,
      requestPath: '/push/channelSubscriptions',
    );
  }

  Future<PaginatedResult<PushChannelSubscription>> _fetchSubscriptionsPage(
    String url,
  ) async {
    final uri = Uri.parse(url);
    final path = uri.path;
    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );
    final items =
        PaginatedResultParser.parsePushChannelSubscriptions(response.body);
    return PaginatedResultImpl.fromResponse<PushChannelSubscription>(
      response: response,
      items: items,
      fetcher: _fetchSubscriptionsPage,
      requestPath: path,
    );
  }

  @override
  Future<PaginatedResult<String>> listChannels(
    Map<String, String> params,
  ) async {
    _logger.info('push.admin.channelSubscriptions.listChannels() called', {});

    final response = await _httpClient.request(
      'GET',
      '/push/channels',
      queryParams: params.isNotEmpty ? params : null,
    );

    final items = PaginatedResultParser.parseStringList(response.body);

    return PaginatedResultImpl.fromResponse<String>(
      response: response,
      items: items,
      fetcher: _fetchChannelsPage,
      requestPath: '/push/channels',
    );
  }

  Future<PaginatedResult<String>> _fetchChannelsPage(String url) async {
    final uri = Uri.parse(url);
    final path = uri.path;
    final response = await _httpClient.request(
      'GET',
      path,
      queryParams: uri.queryParameters.isNotEmpty
          ? Map<String, String>.from(uri.queryParameters)
          : null,
    );
    final items = PaginatedResultParser.parseStringList(response.body);
    return PaginatedResultImpl.fromResponse<String>(
      response: response,
      items: items,
      fetcher: _fetchChannelsPage,
      requestPath: path,
    );
  }

  @override
  Future<PushChannelSubscription> save(
    PushChannelSubscription subscription,
  ) async {
    _logger.info('push.admin.channelSubscriptions.save() called', {
      'channel': subscription.channel,
    });

    final response = await _httpClient.request(
      'POST',
      '/push/channelSubscriptions',
      body: subscription.toMap(),
    );
    return PushChannelSubscription.fromMap(
      response.body as Map<String, dynamic>,
    );
  }

  @override
  Future<void> remove(PushChannelSubscription subscription) async {
    _logger.info('push.admin.channelSubscriptions.remove() called', {
      'channel': subscription.channel,
    });

    // RSH1c4: Send subscription attributes as query params
    final params = <String, String>{
      'channel': subscription.channel,
    };
    if (subscription.deviceId != null) {
      params['deviceId'] = subscription.deviceId!;
    }
    if (subscription.clientId != null) {
      params['clientId'] = subscription.clientId!;
    }

    await _httpClient.request(
      'DELETE',
      '/push/channelSubscriptions',
      queryParams: params,
    );
  }

  @override
  Future<void> removeWhere(Map<String, String> params) async {
    _logger.info('push.admin.channelSubscriptions.removeWhere() called', {});

    await _httpClient.request(
      'DELETE',
      '/push/channelSubscriptions',
      queryParams: params.isNotEmpty ? params : null,
    );
  }
}
