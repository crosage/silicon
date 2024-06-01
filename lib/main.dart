import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_icmp_ping/flutter_icmp_ping.dart';

void main() {
  runApp(PortScannerApp());
}
class ScanResult {
  final String ip;
  final List<String> openPorts;

  ScanResult({required this.ip, required this.openPorts});
}

class PortScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Port Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PortScannerHomePage(),
    );
  }
}

class PortScannerHomePage extends StatefulWidget {
  @override
  _PortScannerHomePageState createState() => _PortScannerHomePageState();
}

class _PortScannerHomePageState extends State<PortScannerHomePage> {
  late TextEditingController _startIPController;
  late TextEditingController _endIPController;
  late TextEditingController _startPortController;
  late TextEditingController _endPortController;
  bool onlyicmp = false;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _startIPController = TextEditingController();
    _endIPController = TextEditingController();
    _startPortController = TextEditingController();
    _endPortController = TextEditingController();
  }

  @override
  void dispose() {
    _startIPController.dispose();
    _endIPController.dispose();
    _startPortController.dispose();
    _endPortController.dispose();
    super.dispose();
  }

  Future<List<String>> scanPorts(String ip, int startPort, int endPort) async {
    List<String> openPorts = [];
    for (int port = startPort; port <= endPort; port++) {
      try {
        Socket socket = await Socket.connect(ip, port, timeout: Duration(seconds: 1));
        openPorts.add(port.toString());
        socket.destroy();
      } catch (e) {
        print("eeeeeeeeeeeeeeer    $e");
      }
    }
    print("*****************");
    return openPorts;
  }
  Future<List<String>> scanPortsThreads(String ip,int startPort,int endPort)async{
    final List<Future<List<String>>> tasks=[];
    // 20个线程
    final threads=20;
    // 每个线程分配多少个端口
    final int portsPerThread=(endPort-startPort+1)~/threads;
    // 现在是哪个端口开始
    int nowStart=startPort;
    for(int i=0;i<threads;i++){
      int nowEnd;
      if(i==threads-1){
        nowEnd=endPort;
      }else {
        nowEnd=nowStart+portsPerThread;
      }
      tasks.add(scanPorts(ip, nowStart, nowEnd));
      nowStart+=portsPerThread;
    }
    List<String> openPorts = [];
    await Future.wait(tasks).then((List<List<String>> results) {
      for (final result in results) {
        openPorts.addAll(result);
      }
    }).catchError((e) {

    });
    return openPorts;
  }
  void _scanIPRange() async {
    _scanResults.clear();
    setState(() {});
    String startIP = _startIPController.text.trim();
    String endIP = _endIPController.text.trim();
    List<String> ipRange = _generateIPRange(startIP, endIP);
    if(onlyicmp==true){
      for (String ip in ipRange) {
        bool able = await _pingIP(ip);
        print(ip);
        if (able) {
          _scanResults.add(ScanResult(ip: ip, openPorts: ["收到icmp报文"]));
          setState(() {});
        }
        else {
          _scanResults.add(ScanResult(ip: ip, openPorts: ["未收到icmp报文"]));
          setState(() {});
        }
      }
    }else {
      int startPort = int.parse(_startPortController.text.trim());
      int endPort = int.parse(_endPortController.text.trim());

      print(ipRange);
      for (String ip in ipRange) {
        List<String> openPorts = await scanPortsThreads(ip, startPort, endPort);
        print(ip);
        if (openPorts.isNotEmpty) {
          _scanResults.add(ScanResult(ip: ip, openPorts: openPorts));
          setState(() {});
        }
        else {
          _scanResults.add(ScanResult(ip: ip, openPorts: ["该主机未有发现开放端口"]));
          setState(() {});
        }
      }
    }
  }
  Future<bool> _pingIP(String ip) async {
    final ping = Ping(
      ip,
      count: 1,
      timeout: 1,
      interval: 1,
      ipv6: false,
      ttl: 40,
    );
    bool able = false;
    await for (PingData event in ping.stream) {
      print(event.response?.ip);
      if (event.response?.ip != null) {
        able = true;
        break;
      }
    }
    print("able=$able");
    return able;
  }

  List<String> _generateIPRange(String startIP, String endIP) {
    List<String> ips = [];
    List<int> startOctets = startIP.split('.').map(int.parse).toList();
    List<int> endOctets = endIP.split('.').map(int.parse).toList();
    for (int i = startOctets[3]; i <= endOctets[3]; i++) {
      ips.add('${startOctets[0]}.${startOctets[1]}.${startOctets[2]}.$i');
    }
    return ips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Port Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startIPController,
                    decoration: InputDecoration(labelText: '起始IP地址'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _endIPController,
                    decoration: InputDecoration(labelText: '结束IP地址'),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startPortController,
                    decoration: InputDecoration(labelText: '起始端口'),
                    keyboardType: TextInputType.number,
                    enabled: !onlyicmp,
                  ),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: TextField(
                    controller: _endPortController,
                    decoration: InputDecoration(labelText: '结束端口'),
                    keyboardType: TextInputType.number,
                    enabled: !onlyicmp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.0),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _scanIPRange,
                  child: Text('开始扫描'),
                ),
                Spacer(),
                Checkbox(
                  value: onlyicmp,
                  onChanged: (value) {
                    setState(() {
                      onlyicmp = value ?? false;
                    });
                  },
                ),
                Text("只进行主机发现"),
              ],
            ),
            SizedBox(height: 20.0),
            Row(
              children: [
                Expanded(
                    child: Text("ip列表",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),)
                ),
                Expanded(
                    child:Text("开放端口列表",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold))
                ),
              ],
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  return Row(
                    children: [
                      Expanded(
                          child:Text(_scanResults[index].ip),
                      ),
                      Expanded(
                          child: Text(_scanResults[index].openPorts.toString())
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
