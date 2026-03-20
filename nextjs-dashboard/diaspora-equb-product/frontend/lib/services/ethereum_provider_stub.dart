bool get hasInjectedProvider => false;

Future<String?> connectViaInjectedProvider() async => null;

Future<String?> personalSignViaInjected(String message, String address) async =>
    null;

Future<String?> sendTransactionViaInjected(Map<String, dynamic> tx) async =>
    null;

Future<void> switchInjectedChain({
    required int chainId,
    required String chainName,
    required List<String> rpcUrls,
    required String symbol,
    required List<String> blockExplorerUrls,
}) async {}
