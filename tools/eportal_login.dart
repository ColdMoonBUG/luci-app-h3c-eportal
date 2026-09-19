// H3C eportal（海君）校园网自动登录 — Flutter/Dart 参考实现
// 对应 luci-app-nbtverify 1.0.8 里跑通的流程。
//
// 依赖: http: ^1.2.0  (pubspec.yaml 里加)
//
// 流程:
//   1. GET 检测地址（默认 http://10.147.103.3/）
//      - 已在线: 返回真实网页/200，不是 <script>top.self.location...
//      - 掉线:   返回 <script>top.self.location.href='<登录页URL>'</script>
//   2. GET 登录页 URL，拿 JSESSIONID cookie（Path=/eportal）
//   3. POST /eportal/InterFace.do?method=login，8 个字段，关键参数双重 URL 编码
//   4. 解析 JSON: {result:"success"|"fail", message, userIndex, keepaliveInterval}

import 'dart:convert';
import 'package:http/http.dart' as http;

class EportalLoginResult {
  final bool success;
  final String message;
  final String userIndex;
  final int keepaliveInterval;
  EportalLoginResult(this.success, this.message, this.userIndex, this.keepaliveInterval);
}

class EportalClient {
  final String baseIp;           // 例如 10.147.103.3
  final String username;          // 学号
  final String password;          // 密码
  final String pingUrl;          // 默认 http://10.147.103.3/

  EportalClient({
    required this.username,
    required this.password,
    String? pingUrl,
  })  : pingUrl = pingUrl ?? 'http://10.147.103.3/',
        baseIp = Uri.parse(pingUrl ?? 'http://10.147.103.3/').host;

  // 手机 UA —— 必须和浏览器一致，服务器按 UA 决定走 PC 端还是手机端表单
  static const _mobileUA =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 14_2 like Mac OS X) '
      'AppleWebKit/604.1.28 (KHTML, like Gecko) CriOS/111.0.5563.8 Mobile/14E5239e Safari/602.1';

  // JS encodeURIComponent 的双重调用。Dart 的 Uri.encodeComponent 语义和 JS 一致。
  String _doubleEnc(String s) => Uri.encodeComponent(Uri.encodeComponent(s));

  /// 返回 null 表示已在线；返回字符串是需要跳去的登录页 URL。
  Future<String?> _detectAndGetLoginPageUrl() async {
    final res = await http.get(Uri.parse(pingUrl), headers: {'User-Agent': _mobileUA});
    final body = res.body;
    // 掉线时门户返回 <script>top.self.location.href='...'</script>
    if (body.contains('top.self.location.href')) {
      final start = body.indexOf("'");
      final end = body.lastIndexOf("'");
      if (start != -1 && end != -1 && end > start) {
        return body.substring(start + 1, end).replaceAll(' ', '');
      }
    }
    return null; // 已在线
  }

  Future<EportalLoginResult> login() async {
    final loginPageUrl = await _detectAndGetLoginPageUrl();
    if (loginPageUrl == null) {
      return EportalLoginResult(true, 'already online', '', 0);
    }

    // Step 2: GET 登录页，拿 JSESSIONID
    final pageUri = Uri.parse(loginPageUrl);
    final pageRes = await http.get(pageUri, headers: {'User-Agent': _mobileUA});
    final cookies = <String, String>{};
    for (final setCookie in pageRes.headers['set-cookie']?.split(',') ?? []) {
      // 只取 name=value 段
      final pair = setCookie.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq > 0) cookies[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
    final cookieHeader = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

    // rawQuery 就是登录页 URL 里 ? 后面那串（wlanuserip/wlanacname/...）
    final rawQuery = pageUri.query;

    // Step 3: POST AJAX 登录
    final loginUri = Uri.parse('http://$baseIp/eportal/InterFace.do?method=login');
    // userId/password/queryString 都已经 doubleEnc 过，直接拼 body 字符串，
    // 不要让 http 包再 encode 一次（否则就三重编码了）。
    final body = [
      'userId=${_doubleEnc(username)}',
      'password=${_doubleEnc(password)}',
      'service=',
      'queryString=${_doubleEnc(rawQuery)}',
      'operatorPwd=',
      'operatorUserId=',
      'validcode=',
      'passwordEncrypt=false',
    ].join('&');

    final postRes = await http.post(
      loginUri,
      headers: {
        'User-Agent': _mobileUA,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Referer': loginPageUrl,
        'Cookie': cookieHeader,
      },
      body: body, // String body: http 不会再 encode
    );

    final text = utf8.decode(postRes.bodyBytes);
    final json = jsonDecode(text) as Map<String, dynamic>;
    return EportalLoginResult(
      json['result'] == 'success',
      json['message'] ?? '',
      json['userIndex'] ?? '',
      (json['keepaliveInterval'] as num?)?.toInt() ?? 0,
    );
  }
}
