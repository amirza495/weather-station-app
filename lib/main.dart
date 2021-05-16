import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(WeatherStationApp());

class WeatherStationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Weather Station',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WeatherPage(title: 'Weather'),
    );
  }
}

class WeatherPage extends StatefulWidget {
  WeatherPage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final Map<DeviceIdentifier, BluetoothDevice> devicesList = {};
  final WeatherState weather = new WeatherState();
  final Map<String, Guid> guidMap = {
    'weather_att': Guid('0000181a-0000-1000-8000-00805f9b34fb'),
    'temp_char': Guid('00002a6e-0000-1000-8000-00805f9b34fb'),
    'press_char': Guid('00002a6d-0000-1000-8000-00805f9b34fb'),
    'humid_char': Guid('00002a6f-0000-1000-8000-00805f9b34fb'),
  };
  final DeviceIdentifier WeatherStationMAC =
      DeviceIdentifier("EB:B4:21:FD:7C:BE");

  @override
  _WeatherPageState createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  BluetoothDevice _connectedDevice;
  String _deviceStatus = "Not Connected";
  List<BluetoothService> _services;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.containsKey(device.id)) {
      setState(() {
        widget.devicesList[device.id] = device;
      });
    }
  }

  int byteListToInt(List value) {
    Uint8List byteList = Uint8List.fromList(value);
    ByteData byteData = ByteData.sublistView(byteList);
    int len = byteData.lengthInBytes;
    switch (len) {
      case 2:
        {
          return byteData.getInt16(0, Endian.little);
        }
      case 4:
        {
          return byteData.getUint32(0, Endian.little);
        }
      default:
        {
          return 0;
        }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // connection button
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    widget.flutterBlue.stopScan();
                    debugPrint(widget.devicesList.toString());
                    BluetoothDevice device =
                        widget.devicesList[widget.WeatherStationMAC];
                    debugPrint(device.name);
                    try {
                      await device.connect();
                    } catch (e) {
                      if (e.code != 'already_connected') {
                        throw e;
                      }
                    } finally {
                      _services = await device.discoverServices();
                    }
                    debugPrint("Device Connected");
                    setState(() {
                      _connectedDevice = device;
                      _deviceStatus = "Connected";
                    });
                  },
                  child: Text("Connect"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Weather Station Status: "),
                    Text(
                      _deviceStatus.toString(),
                    )
                  ],
                )
              ],
            ),
          ),
          // weather data section
          Expanded(
            child: ListView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(32),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text("Temperature:"),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          widget.weather.temperatureF.toStringAsFixed(1) +
                              " " +
                              String.fromCharCode(0x00B0) +
                              "F"),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text("Pressure:"),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          widget.weather.pressureInHg.toStringAsFixed(3) +
                              " in Hg"),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text("Humidity:"),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          widget.weather.humidityPercent.toStringAsFixed(2) +
                              "%"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // sample button
          Container(
            padding: const EdgeInsets.all(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    int temp = 0, press = 0, humid = 0;
                    for (BluetoothService s in _services) {
                      for (BluetoothCharacteristic c in s.characteristics) {
                        if (c.uuid == widget.guidMap['temp_char']) {
                          // temperature
                          var sub = c.value.listen((v) {
                            temp = byteListToInt(v);
                          });
                          await c.read();
                          sub.cancel();
                        } else if (c.uuid == widget.guidMap['press_char']) {
                          // pressure
                          var sub = c.value.listen((v) {
                            press = byteListToInt(v);
                          });
                          await c.read();
                          sub.cancel();
                        } else if (c.uuid == widget.guidMap['humid_char']) {
                          // humidity
                          var sub = c.value.listen((v) {
                            humid = byteListToInt(v);
                          });
                          await c.read();
                          sub.cancel();
                        }
                      }
                    }
                    setState(() {
                      widget.weather.updateWeather(temp, press, humid);
                    });
                  },
                  child: Text("Sample"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// storage and calculation of weather properties
class WeatherState {
  // output weather values
  double pressureInHg = 0.0;
  double temperatureF = 0.0;
  double humidityPercent = 0.0;

  // class constructor
  WeatherState();

  // update weather state based on a measurement
  void updateWeather(int temp, int press, int humid) {
    // convert raw weather measurement values to doubles
    double tempD = temp / 100.0;
    double pressD = press / 10.0;
    double humidD = humid / 100.0;

    // convert weather to useful quantities
    this.temperatureF = tempCToF(tempD);
    this.pressureInHg = pressPatoInHg(pressD);
    this.humidityPercent = humidD;
  }

  // convert temp in C to temp in F
  double tempCToF(double temp) {
    return 9 / 5 * temp + 32;
  }

  // convert pressure from Pa to mmHg
  double pressPatoInHg(double press) {
    return press / 3386.3886666667;
  }
}
