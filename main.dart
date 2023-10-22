// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'mongodb.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.requestPermission();
  runApp(const MyApp());
}

class TripData {
  String? startLocation;
  String? endLocation;
  String? tripMode;
  DateTime? startTimeStamp;
  DateTime? endTimeStamp;

  TripData({
    this.startLocation,
    this.endLocation,
    this.tripMode,
    this.startTimeStamp,
    this.endTimeStamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'startLocation': startLocation,
      'endLocation': endLocation,
      'tripMode': tripMode,
      'startTimeStamp': startTimeStamp?.toString(),
      'endTimeStamp': endTimeStamp?.toString(),
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepPurple,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String tripStatus = 'Trip Not Started';
  String? tripMode;
  String? userName;
  TripData? tripData;
  final TripStorage tripStorage = TripStorage();

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    tripStorage.loadTripData().then((data) {
      setState(() {
        tripData = data;
        if (tripData != null) {
          if (tripData!.startLocation != null &&
              tripData!.endLocation != null &&
              tripData!.tripMode != null &&
              tripData!.startTimeStamp != null &&
              tripData!.endTimeStamp != null) {
            tripStatus = 'Trip Started';
          }
        } else {
          tripData = TripData();
        }
      });
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserName = prefs.getString('userName');
    if (storedUserName != null) {
      setState(() {
        userName = storedUserName;
      });
    }
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
  }

  Future<void> getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      if (tripData != null) {
        tripData!.startLocation = '${position.latitude}, ${position.longitude}';
        tripData!.startTimeStamp = DateTime.now();
      } else {
        tripData = TripData(
          startLocation: '${position.latitude}, ${position.longitude}',
          startTimeStamp: DateTime.now(),
        );
      }
    });
    await tripStorage.saveTripData(tripData!);
  }

  void endTrip() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      tripData!.endLocation = '${position.latitude}, ${position.longitude}';
      tripData!.endTimeStamp = DateTime.now();
      tripStatus = 'Trip Ended';
    });

    await tripStorage.saveTripData(tripData!);
    await tripStorage.sendTripDataToMongoDB(tripData!, userName);
    tripStorage.clearTripData();
  }

  void restartTrip() {
    setState(() {
      tripStatus = 'Trip Not Started';
      tripData = null;
    });
    tripStorage.clearTripData();
  }

  void onModeChanged(String? value) {
    setState(() {
      tripMode = value;
      if (tripData != null) {
        tripData!.tripMode = value;
        tripStorage.saveTripData(tripData!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        title: const Text('Trip Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(50),
              ),
              padding: const EdgeInsets.all(20),
              child: Text(
                tripStatus,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),
            if (userName == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter your name',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (userName == null)
              ElevatedButton(
                onPressed: () async {
                  String name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    setState(() {
                      userName = name;
                    });
                    await _saveUserName(name);
                  }
                },
                child: const Text('Submit'),
              ),
            if (userName != null)
              ElevatedButton(
                onPressed: () {
                  getLocation();
                  setState(() {
                    tripStatus = 'Trip Started';
                  });
                },
                child: const Text('Start Trip'),
              ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: tripMode,
              onChanged: onModeChanged,
              items: const [
                DropdownMenuItem(value: 'Car', child: Text('Car')),
                DropdownMenuItem(value: 'Walking', child: Text('Walking')),
                DropdownMenuItem(value: 'Bike', child: Text('Bike')),
                DropdownMenuItem(value: 'Cycle', child: Text('Cycle')),
                DropdownMenuItem(value: 'Rickshaw', child: Text('Rickshaw')),
                DropdownMenuItem(
                    value: 'E-Rickshaw', child: Text('E-Rickshaw')),
                DropdownMenuItem(value: 'CNG', child: Text('CNG')),
                DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                DropdownMenuItem(value: 'MRT', child: Text('MRT')),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: endTrip,
              child: const Text('End Trip'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: restartTrip,
              child: const Text('Restart Trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class TripStorage {
  final String key = 'tripData';

  Future<void> saveTripData(TripData tripData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(tripData.toMap()));
  }

  Future<TripData?> loadTripData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      final dataMap = jsonDecode(jsonString);
      return TripData(
        startLocation: dataMap['startLocation'],
        endLocation: dataMap['endLocation'],
        tripMode: dataMap['tripMode'],
        startTimeStamp: DateTime.parse(dataMap['startTimeStamp']),
        endTimeStamp: DateTime.parse(dataMap['endTimeStamp']),
      );
    }
    return null;
  }

  Future<void> clearTripData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> sendTripDataToMongoDB(
      TripData tripData, String? userName) async {
    if (userName != null) {
      Map<String, dynamic> dataWithUserName = {
        ...tripData.toMap(),
        'userName': userName,
      };
      await MongoDatabase.insertTripData(dataWithUserName);
    }
  }
}
