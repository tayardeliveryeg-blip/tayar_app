import 'package:latlong2/latlong.dart';

class NearbyDriverMarker {
  LatLng displayed;
  LatLng prev;
  LatLng target;

  NearbyDriverMarker({required this.displayed, required this.prev, required this.target});
}
