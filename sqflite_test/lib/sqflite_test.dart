library sqflite_test;

import 'dart:async';
import 'package:test_api/test_api.dart';
import 'package:path/path.dart';
import 'package:sqflite_server/sqflite.dart';
import 'package:tekartik_common_utils/int_utils.dart';
// ignore: implementation_imports
import 'package:sqflite_server/src/sqflite_client.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/which.dart';

class SqfliteServerTestContext extends SqfliteServerContext {
  String envUrl;
  int envPort;
  String url;

  Future<SqfliteClient> connectClientPort({int port}) async {
    if (client == null) {
      if (port != null) {
        url = getSqfliteServerUrl(port: port);
      } else {
        envUrl = const String.fromEnvironment(sqfliteServerUrlEnvKey);
        envPort =
            parseInt(const String.fromEnvironment(sqfliteServerPortEnvKey));

        url = envUrl;
        if (url == null) {
          url = getSqfliteServerUrl(port: envPort);
        }
      }

      port ??= parseSqfliteServerUrlPort(url, defaultValue: 0);

      // Run the needed adb command if no env overrides
      if (envUrl == null && envPort == null) {
        try {
          await runCmd(ProcessCmd(
              whichSync('adb'), ['forward', 'tcp:$port', 'tcp:$port'])
            ..runInShell = true);
        } catch (_) {}
      }

      try {
        await connectClient(url);
      } catch (e) {
        print(e);
      }
      if (client == null) {
        print('''
sqflite server not running on $url
Check that the sqflite_server_app is running on the proper port on a connected
iOS device/simulator, Android device/emulator

Android: 
  check that you have forwarded tcp ip on Android
  \$ adb forward tcp:$port tcp:$port

''');
        if (port == null) {
          print('''
url/port can be overriden using env variables
$sqfliteServerUrlEnvKey: ${envUrl ?? ''}
$sqfliteServerPortEnvKey: ${envPort ?? ''}

''');
        }
      }
    }
    return client;
  }

  Future<String> initDeleteDb(String dbName) async {
    var databasesPath = await createDirectory(null);
    // print(databasePath);
    String path = join(databasesPath, dbName);
    await databaseFactory.deleteDatabase(path);
    return path;
  }

  static Future<SqfliteServerTestContext> connect() async {
    var context = SqfliteServerTestContext();
    var sqfliteClient = await context.connectClientPort();
    if (sqfliteClient == null) {
      var url = context.url;
      var port = parseSqfliteServerUrlPort(url);
      print('''
sqflite server not running on $url
Check that the sqflite_server_app is running on the proper port
Android: 
  check that you have forwarded tcp ip on Android
  \$ adb forward tcp:$port tcp:$port

''');
    } else {
      return context;
    }
    return null;
  }

  @override
  Future close() async {
    await client?.close();
  }

  @override
  Future<T> sendRequest<T>(String method, dynamic param) async {
    if (_debugModeOn) {
      print('$param');
    }
    T t = await super.sendRequest(method, param);
    if (_debugModeOn) {
      print(t);
    }
    return t;
  }

  @override
  Future<T> invoke<T>(String method, dynamic param) async {
    T t = await super.invoke(method, param);
    return t;
  }

  bool _debugModeOn = false;

  @deprecated
  Future devSetDebugModeOn(bool on) async {
    _debugModeOn = on ?? false;
  }
}

/// Main entry point for with Sqflite context
Future testMain(void Function(SqfliteServerTestContext context) run) async {
  var context = await SqfliteServerTestContext.connect();
  if (context == null) {
    test('connected', () {}, skip: true);
  } else {
    run(context);
  }
  tearDownAll(() async {
    await context?.close();
  });
}

// void run(SqfliteServerTestContext context) {
