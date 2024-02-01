import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info/device_info.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}


Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => Home());
    case 'browser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.browser));
    case 'advertiser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.advertiser));
    default:
      return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
                child: Text('No route defined for ${settings.name}')),
          ));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: '/',
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'browser');
              },
              child: Container(
                color: Colors.red,
                child: Center(
                    child: Text(
                      'BROWSER',
                      style: TextStyle(color: Colors.white, fontSize: 40),
                    )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'advertiser');
              },
              child: Container(
                color: Colors.green,
                child: Center(
                    child: Text(
                      'ADVERTISER',
                      style: TextStyle(color: Colors.white, fontSize: 40),
                    )),
              ),
            ),
          ),

    // Button to navigate to LocalDataScreen
        ElevatedButton(
        onPressed: () {
        Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LocalDataScreen()),
        );
        },
        child: Text('View Local Data'),
        ),
        ],
      ),
    );
  }
}

enum DeviceType { advertiser, browser }

class LocalDataScreen extends StatefulWidget {
  @override
  _LocalDataScreenState createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends State<LocalDataScreen> {
  List<String> storedData = [];

  @override
  void initState() {
    super.initState();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      storedData = prefs.getStringList('storedData') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local Data'),
      ),
      body: ListView.builder(
        itemCount: storedData.length,
        itemBuilder: (context, index) {
          final Map<String, dynamic> data = jsonDecode(storedData[index]);
          return ListTile(

            title: Text('connected device UDID: ${data['number2']}'),
            subtitle: Text('date/time: ${data['timestamp']}'),
            // Add more fields as needed
          );
        },
      ),
    );
  }
}

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({required this.deviceType});

  final DeviceType deviceType;

  @override
  _DevicesListScreenState createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
  List<Device> devices = [];
  List<Device> connectedDevices = [];
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  late StreamSubscription receivedDataSubscription;

  bool isInit = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    subscription.cancel();
    receivedDataSubscription.cancel();
    nearbyService.stopBrowsingForPeers();
    nearbyService.stopAdvertisingPeer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.deviceType.toString().substring(11).toUpperCase()),
        ),
        backgroundColor: Colors.white,
        body: ListView.builder(
            itemCount: getItemCount(),
            itemBuilder: (context, index) {
              final device = widget.deviceType == DeviceType.advertiser
                  ? connectedDevices[index]
                  : devices[index];
              return Container(
                margin: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: GestureDetector(
                              onTap: () => _onTabItemListener(device),
                              child: Column(
                                children: [
                                  Text(device.deviceName),
                                  Text(
                                    getStateName(device.state),
                                    style: TextStyle(
                                        color: getStateColor(device.state)),
                                  ),
                                ],
                                crossAxisAlignment: CrossAxisAlignment.start,
                              ),
                            )),
                        // Request connect
                        GestureDetector(
                          onTap: () => _onButtonClicked(device),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.0),
                            padding: EdgeInsets.all(8.0),
                            height: 35,
                            width: 100,
                            color: getButtonColor(device.state),
                            child: Center(
                              child: Text(
                                getButtonStateName(device.state),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(
                      height: 8.0,
                    ),
                    Divider(
                      height: 1,
                      color: Colors.grey,
                    )
                  ],
                ),
              );
            }));
  }

  String getStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return "disconnected";
      case SessionState.connecting:
        return "waiting";
      default:
        return "connected";
    }
  }

  String getButtonStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
      case SessionState.connecting:
        return "Connect";
      default:
        return "Disconnect";
    }
  }

  Color getStateColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return Colors.black;
      case SessionState.connecting:
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  Color getButtonColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
      case SessionState.connecting:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  _onTabItemListener(Device device) {
    if (device.state == SessionState.connected) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            final myController = TextEditingController();
            return AlertDialog(
              title: Text("Send message"),
              content: TextField(controller: myController),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("Send"),
                  onPressed: () {
                    nearbyService.sendMessage(
                        device.deviceId, myController.text);
                    myController.text = '';
                  },
                )
              ],
            );
          });
    }
  }

  int getItemCount() {
    if (widget.deviceType == DeviceType.advertiser) {
      return connectedDevices.length;
    } else {
      return devices.length;
    }
  }

  _onButtonClicked(Device device) async {
    switch (device.state) {
      case SessionState.notConnected:
        nearbyService.invitePeer(
          deviceID: device.deviceId,
          deviceName: device.deviceName,
        );
        break;
      case SessionState.connected:
        nearbyService.disconnectPeer(deviceID: device.deviceId);
        break;
      case SessionState.connecting:
        break;
    }
  }
  String connectedDeviceUDID = ''; // Define a variable to store the connected device UDID
  Device? connectedDevice;


  Future<String> generateUDID() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storedUDID = prefs.getString('udid');

    if (storedUDID != null) {
      return storedUDID;
    } else {
      final uuid = Uuid();
      final newUDID = uuid.v4();

      // Store the new UDID locally
      await prefs.setString('udid', newUDID);

      return newUDID;
    }
  }


  void init() async {
    nearbyService = NearbyService();
    final connectivityResult = await (Connectivity().checkConnectivity());
    String devInfo = '';
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      devInfo = androidInfo.model;
    }
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      devInfo = iosInfo.localizedModel;
    }


    Future<bool> isInternetAvailable() async {
      // Check for internet connectivity here
      // You can use a package like `connectivity` for this purpose
      // Example: https://pub.dev/packages/connectivity
      if (connectivityResult == ConnectivityResult.wifi) {
        // I am connected to a wifi network.
       return true;
      }else {
        return false;
      }// Placeholder, replace with actual internet check
    }

    Future<void> storeLocalData(Map<String, dynamic> data) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> storedData = prefs.getStringList('storedData') ?? [];

      // Add the new data to the list
      storedData.add(jsonEncode(data));

      // Save the updated list
      await prefs.setStringList('storedData', storedData);
    }


    Future<void> sendToServer(Map<String, dynamic> data) async {
      final url = 'http://192.168.137.249:8080/api/saveNumber'; // Replace with your actual server API endpoint

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print('UDIDs sent successfully');
      } else {
        print('Failed to send UDIDs. Status code: ${response.statusCode}');
      }
    }

    Future<void> sendUDIDsToServer(String currentDeviceUDID, String connectedDeviceUDID) async {
      final DateTime currentTime = DateTime.now();

      final Map<String, dynamic> dataToSend = {
        'number1': currentDeviceUDID,
        'number2': connectedDeviceUDID,
        'timestamp': currentTime.toIso8601String(),
      };



      // Store the data locally


      // Check for internet connection
      if (await isInternetAvailable()) {

        await sendToServer(dataToSend);
      } else {
        print('No internet connection. Data stored locally.');
        await storeLocalData(dataToSend);

      }
    }
    await nearbyService.init(
      serviceType: 'mpconn',
      deviceName: devInfo,
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning) {
          if (widget.deviceType == DeviceType.browser) {
            await nearbyService.stopBrowsingForPeers();
            await Future.delayed(Duration(microseconds: 200));
            await nearbyService.startBrowsingForPeers();
          } else {
            await nearbyService.stopAdvertisingPeer();
            await nearbyService.stopBrowsingForPeers();
            await Future.delayed(Duration(microseconds: 200));
            await nearbyService.startAdvertisingPeer();
            await nearbyService.startBrowsingForPeers();
          }
        }
      },
    );

    subscription = nearbyService.stateChangedSubscription(callback: (devicesList) {
      devicesList.forEach((element) async {


        if (element.state == SessionState.notConnected) {
          nearbyService.invitePeer(
            deviceID: element.deviceId,
            deviceName: element.deviceName,
          );
        } else if (element.state == SessionState.connected &&
            connectedDevices.isEmpty) {
          // Store the connected device information
          connectedDevice = element;

          // Obtain the UDID of the connected device
          connectedDeviceUDID = await generateUDID();

          // Send the UDID to the connected device
          nearbyService.sendMessage(
            connectedDevice!.deviceId,
            connectedDeviceUDID,
          );
        }
      });

      setState(() {
        devices.clear();
        devices.addAll(devicesList);
        connectedDevices.clear();
        connectedDevices.addAll(devicesList
            .where((d) => d.state == SessionState.connected)
            .toList());
      });
    });

    receivedDataSubscription =
        nearbyService.dataReceivedSubscription(callback: (data) async {

          var test = await generateUDID();

          if (widget.deviceType == DeviceType.browser) {
            sendUDIDsToServer(test, data['message']);
          }





          showToast(
            jsonEncode(data['message']),
            context: context,
            axis: Axis.horizontal,
            alignment: Alignment.center,
            position: StyledToastPosition.bottom,
          );
        });
  }



}