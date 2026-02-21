import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get hasInjectedProvider => globalContext.has('ethereum');

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
  final promise = ethereum.callMethod<JSPromise>('request'.toJS, params);
  final result = await promise.toDart;

  if (result == null) return null;
  return (result as JSString).toDart;
}

Future<String?> sendTransactionViaInjected(Map<String, dynamic> tx) async {
  if (!hasInjectedProvider) return null;

  final ethereum = globalContext['ethereum'] as JSObject;
  final params = {
    'method': 'eth_sendTransaction',
    'params': [tx],
  }.jsify();
  final promise = ethereum.callMethod<JSPromise>('request'.toJS, params);
  final result = await promise.toDart;

  if (result == null) return null;
  return (result as JSString).toDart;
}
