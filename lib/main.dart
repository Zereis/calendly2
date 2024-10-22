import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth/flutter_web_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendly Meeting Creator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MeetingCreator(),
    );
  }
}

class MeetingCreator extends StatefulWidget {
  const MeetingCreator({super.key});

  @override
  _MeetingCreatorState createState() => _MeetingCreatorState();
}

class _MeetingCreatorState extends State<MeetingCreator> {
  String inviteeEmail = '';
  String responseMessage = '';
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String accessToken = '';
  List<String> eventTypeUris = [];
  String? selectedEventTypeUri;

  final String clientId = '-1DVXpWjN1JpMSdqINrBdbvNdxv2pHzyAbwT35qZZmk';
  
  final String redirectUri = 'https://api.calendly.com/event_types/ABC123';
  final String authorizationEndpoint = 'https://auth.calendly.com/oauth/authorize';
  final String tokenEndpoint = 'https://auth.calendly.com/oauth/token';
  final String eventTypesEndpoint = 'https://api.calendly.com/event_types';

  Future<void> initiateOAuth() async {
    final url = Uri.parse(
        '$authorizationEndpoint?client_id=${Uri.encodeComponent(clientId)}&response_type=code&redirect_uri=${Uri.encodeComponent(redirectUri)}&scope=${Uri.encodeComponent("scheduling user")}'); // Updated scope

    print('Initiating OAuth...'); // Debugging statement
    print('Request URL: $url'); // Log the constructed URL

    try {
      final result = await FlutterWebAuth.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'myapp',
      );

      final code = Uri.parse(result).queryParameters['code'];

      if (code != null) {
        await exchangeAuthorizationCodeForToken(code);
      } else {
        setState(() {
          responseMessage = 'Failed to get authorization code';
          print('Failed to get authorization code');
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = 'OAuth failed: $e';
        print('OAuth failed: $e'); // Debugging statement
      });
    }
  }

  Future<void> exchangeAuthorizationCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    print('Response from token exchange: ${response.body}'); // Debugging statement

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        accessToken = responseData['access_token'];
        responseMessage = 'OAuth authentication successful!';
      });
      await fetchEventTypes();
    } else {
      setState(() {
        responseMessage =
            'Failed to exchange authorization code: ${response.statusCode} - ${response.body}'; // Add body for debugging
      });
    }
  }

  Future<void> fetchEventTypes() async {
    final response = await http.get(
      Uri.parse(eventTypesEndpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Response from fetching event types: ${response.body}'); // Debugging statement

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        eventTypeUris = responseData['collection']
            .map<String>((event) => event['uri'])
            .toList()
            .cast<String>();
        responseMessage = 'Event types fetched successfully!';
      });
    } else {
      setState(() {
        responseMessage =
            'Failed to fetch event types: ${response.statusCode} - ${response.body}'; // Add body for debugging
      });
    }
  }

  Future<void> createMeeting() async {
    if (accessToken.isEmpty) {
      setState(() {
        responseMessage = 'You need to authenticate with Calendly first';
      });
      return;
    }

    if (selectedEventTypeUri == null) {
      setState(() {
        responseMessage = 'Please select an event type.';
      });
      return;
    }

    final url = Uri.parse('https://calendly.com/davidvinhthanhhoang/test');

    setState(() {
      isLoading = true; // Start loading
    });

    DateTime startDateTime = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, selectedTime.hour, selectedTime.minute);
    DateTime endDateTime = startDateTime.add(const Duration(hours: 1));
    String startTime = startDateTime.toUtc().toIso8601String();
    String endTime = endDateTime.toUtc().toIso8601String();

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "event": {
            "event_type": selectedEventTypeUri,
            "invitee": {
              "email": inviteeEmail,
            },
            "start_time": startTime,
            "end_time": endTime,
          }
        }),
      );

      print('Response from creating meeting: ${response.body}'); // Debugging statement

      setState(() {
        isLoading = false; // End loading
        if (response.statusCode == 201) {
          responseMessage = 'Meeting created successfully: ${response.body}';
        } else {
          responseMessage =
              'Failed to create meeting: ${response.statusCode} - ${response.body}'; // Add body for debugging
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false; // End loading
        responseMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Meeting in Calendly'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                inviteeEmail = value; // Store email input
              },
              decoration: const InputDecoration(
                labelText: 'Invitee Email',
              ),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              hint: const Text('Select Event Type'),
              value: selectedEventTypeUri,
              items: eventTypeUris.map((String uri) {
                return DropdownMenuItem<String>(
                  value: uri,
                  child: Text(uri.split('/').last),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedEventTypeUri = newValue;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (accessToken.isEmpty) {
                  initiateOAuth(); // Start OAuth flow if not authenticated
                } else if (inviteeEmail.isNotEmpty) {
                  createMeeting(); // Create meeting using the selected event type
                } else {
                  setState(() {
                    responseMessage = 'Please enter an email address.';
                  });
                }
              },
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Meeting'),
            ),
            const SizedBox(height: 20),
            Text(responseMessage), // Display response message
          ],
        ),
      ),
    );
  }
}
