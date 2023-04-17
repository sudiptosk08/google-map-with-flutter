import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class CurrentLocationScreen extends StatefulWidget {
  const CurrentLocationScreen({Key? key}) : super(key: key);

  @override
  _CurrentLocationScreenState createState() => _CurrentLocationScreenState();
}

class _CurrentLocationScreenState extends State<CurrentLocationScreen> {
  late GoogleMapController googleMapController;

  CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(37.42796133580664, -122.085749655962), zoom: 17);

  Set<Marker> markers = {};

  var _controller = TextEditingController();
  var uuid = new Uuid();
  String _sessionToken = '1234567890';
  List<dynamic> _placeList = [];
  bool listTile = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      _onChanged();
      markers = Set.from([]);
    });
  }

  _onChanged() {
    if (_sessionToken == null) {
      setState(() {
        _sessionToken = uuid.v4();
      });
    }
    getSuggestion(_controller.text);
  }

  void getSuggestion(String input) async {
    String kPLACES_API_KEY = "AIzaSyDQ2c_pOSOFYSjxGMwkFvCVWKjYOM9siow";
    String type = '(regions)';

    try {
      String baseURL =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      String request =
          '$baseURL?input=$input&key=$kPLACES_API_KEY&sessiontoken=$_sessionToken';
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);
      print('mydata');
      print(data);
      if (response.statusCode == 200) {
        setState(() {
          _placeList = json.decode(response.body)['predictions'];
        });
      } else {
        throw Exception('Failed to load predictions');
      }
    } catch (e) {
// toastMessage('success');
    }
  }

  //// tap on pick location
  BitmapDescriptor? customIcon;

  createMarker(context) {
    if (customIcon == null) {
      ImageConfiguration configuration = createLocalImageConfiguration(
        context,
      );
      BitmapDescriptor.fromAssetImage(
        configuration,
        "assets/images/location-48.png",
      ).then((icon) {
        setState(() {
          customIcon = icon;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    createMarker(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("User current location"),
        centerTitle: true,
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: initialCameraPosition,
          markers: markers,
          onTap: (pos) {
            print(pos);
            Marker m = Marker(
                markerId: MarkerId('1'), icon: customIcon!, position: pos);
            setState(() {
              markers.add(m);
              CameraPosition(
                  target: LatLng(pos.latitude, pos.longitude), zoom: 17);
              print(pos.latitude);
              print(pos.longitude);
            });
          },
          zoomControlsEnabled: false,
          buildingsEnabled: true,
          mapType: MapType.normal,
          onMapCreated: (GoogleMapController controller) {
            googleMapController = controller;
          },
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 80,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _controller,
                    onTap: () => listTile = true,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: "Seek your location here",
                      focusColor: Colors.white,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      prefixIcon: Icon(Icons.location_on),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.cancel),
                        onPressed: () {
                          _controller.clear();
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 12),
                      border: const UnderlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15.0)),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ),
              ),
            ),
            if (listTile == true)
              Padding(
                padding: EdgeInsets.only(left: 8.0, right: 8.0),
                child: Expanded(
                  child: Container(
                    color: Colors.white,
                    child: ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _placeList.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () async {
                            var add = await locationFromAddress(
                                _placeList[index]["description"]);
                            // ;
                            // var second = add.first;
                            // print("${second.featureName} : ${second.coordinates}");
                            print(add.last.longitude);
                            googleMapController.animateCamera(
                                CameraUpdate.newCameraPosition(CameraPosition(
                                    target: LatLng(
                                        add.last.latitude, add.last.longitude),
                                    zoom: 17)));

                            markers.clear();

                            markers.add(Marker(
                                markerId: const MarkerId('currentLocation'),
                                position: LatLng(
                                    add.last.latitude, add.last.longitude)));

                            setState(() {
                              _controller.text =
                                  _placeList[index]["description"];
                              listTile = false;
                            });
                          },
                          child: ListTile(
                            dense: false,
                            visualDensity: VisualDensity(vertical: -4),
                            title: Text(_placeList[index]["description"]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
          ],
        ),
      ]),
      floatingActionButton: Center(
        heightFactor: 1,
        child: FloatingActionButton.extended(
          onPressed: () async {
            Position position = await _determinePosition();

            googleMapController.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 17)));

            markers.clear();

            markers.add(Marker(
                markerId: const MarkerId('currentLocation'),
                position: LatLng(position.latitude, position.longitude)));

            setState(() {});
          },
          label: const Text("Current Location"),
          icon: const Icon(Icons.location_history),
        ),
      ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        return Future.error("Location permission denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    Position position = await Geolocator.getCurrentPosition();

    return position;
  }
}
