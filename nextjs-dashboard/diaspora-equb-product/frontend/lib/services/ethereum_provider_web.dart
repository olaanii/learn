import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get hasInjectedProvider => globalContext.has('ethereum');

/// Extract a human-readable message from a JS error object.
/// MetaMask errors are typically `{ code: number, message: string, data?: { message } }`.
String _extractJsErrorMessage(Object e) {
  try {
    if (e is JSObject) {
      final msg = e.getProperty<JSAny?>('message'.toJS);
      if (msg != null && msg is JSString) {
        final dartMsg = msg.toDart;
        if (dartMsg.isNotEmpty) return dartMsg;
      }
      // Some errors nest the reason inside data.message
      final data = e.getProperty<JSAny?>('data'.toJS);
      if (data != null && data is JSObject) {
        final dataMsg = data.getProperty<JSAny?>('message'.toJS);
        if (dataMsg != null && dataMsg is JSString) {
          final dartDataMsg = dataMsg.toDart;
          if (dartDataMsg.isNotEmpty) return dartDataMsg;
        }
      }
    }
  } catch (_) {}
  final s = e.toString();
  if (s == '[object Object]') return 'Unknown wallet error';
  return s;
}

Future<String?> connectViaInjectedProvider() async {
  if (!hasInjectedProvider) return null;

  final ethereum = globalContext['ethereum'] as JSObject;
  final params = {'method': 'eth_requestAccounts'}.jsify();
  final promise = ethereum.callMethod<JSPromise>('request'.toJS, params);
  final result = await promise.toDart;

  if (result == null) return null;
  final accounts = (result as JSArray).toDart;
  if (accounts.isEmpty) return null;
  return (accounts.first as JSString).toDart;
}

Future<String?> personalSignViaInjected(String message, String address) async {
  if (!hasInjectedProvider) return null;

  final ethereum = globalContext['ethereum'] as JSObject;
  final hexMessage =
      '0x${message.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';
  final params = {
    'method': 'personal_sign',
    'params': [hexMessage, address],
  }.jsify();

  try {
    final promise = ethereum.callMethod<JSPromise>('request'.toJS, params);
    final result = await promise.toDart;
    if (result == null) return null;
    return (result as JSString).toDart;
  } catch (e) {
    throw Exception(_extractJsErrorMessage(e));
  }
}

Future<String?> sendTransactionViaInjected(Map<String, dynamic> tx) async {
  if (!hasInjectedProvider) return null;

  final cleanTx = <String, dynamic>{};
  for (final entry in tx.entries) {
    if (entry.value != null) cleanTx[entry.key] = entry.value;
  }

  final ethereum = globalContext['ethereum'] as JSObject;
  final params = {
    'method': 'eth_sendTransaction',
    'params': [cleanTx],
  }.jsify();

  try {
    final promise = ethereum.callMethod<JSPromise>('request'.toJS, params);
    final result = await promise.toDart;
    if (result == null) return null;
    return (result as JSString).toDart;
  } catch (e) {
    throw Exception(_extractJsErrorMessage(e));
  }
}

Future<void> switchInjectedChain({
  required int chainId,
  required String chainName,
  required List<String> rpcUrls,
  required String symbol,
  required List<String> blockExplorerUrls,
}) async {
  if (!hasInjectedProvider) return;

  final ethereum = globalContext['ethereum'] as JSObject;
  final hexChainId = '0x${chainId.toRadixString(16)}';

  try {
    final switchParams = {
      'method': 'wallet_switchEthereumChain',
      'params': [
        {'chainId': hexChainId}
      ],
    }.jsify();
    final promise = ethereum.callMethod<JSPromise>('request'.toJS, switchParams);
    await promise.toDart;
  } catch (e) {
    final message = _extractJsErrorMessage(e);
    final knownMissingChain = message.contains('4902') ||
        message.toLowerCase().contains('unrecognized chain');
    if (!knownMissingChain) {
      throw Exception(message);
    }

    final addParams = {
      'method': 'wallet_addEthereumChain',
      'params': [
        {
          'chainId': hexChainId,
          'chainName': chainName,
          'rpcUrls': rpcUrls,
          'nativeCurrency': {
            'name': symbol,
            'symbol': symbol,
            'decimals': 18,
          },
          'blockExplorerUrls': blockExplorerUrls,
        }
      ],
    }.jsify();

    try {
      final promise = ethereum.callMethod<JSPromise>('request'.toJS, addParams);
      await promise.toDart;
    } catch (addError) {
      throw Exception(_extractJsErrorMessage(addError));
    }
  }
}
