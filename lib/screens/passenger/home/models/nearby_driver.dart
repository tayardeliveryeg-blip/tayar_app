import 'package:latlong2/latlong.dart';

class NearbyDriver {
  LatLng displayed;
  LatLng prev;
  LatLng target;

  NearbyDriver({required this.displayed, required this.prev, required this.target});
}
