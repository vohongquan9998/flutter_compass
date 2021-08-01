import 'dart:convert';

import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_compass_app/api.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:sensors/sensors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int mode = 0, map = 0;
  AniControl compass;
  AniControl earth;
  double lat, lon;

  String city = '', weather = '', icon = '01d';
  double temp = 0, humidity = 0;

  void getWeather() async {
    var url =
        'http://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$API_KEY';
    var resp = await http.Client().get(url);
    var data = json.decode(resp.body);
    city = data['name'];
    var m = data['weather'][0];
    weather = m['main'];
    icon = m['icon'];
    m = data['main'];
    temp = m['temp'] - 273.15;
    humidity = m['humidity'] + 0.0;
    setState(() {});
  }

  void setLocation(double lati, double long, [bool weather = true]) {
    earth['lat'].value = lat = lati;
    earth['lon'].value = lon = long;
    if (weather) getWeather();
    setState(() {});
  }

  void locate() => Location()
      .getLocation()
      .then((p) => setLocation(p.latitude, p.longitude));

  @override
  void initState() {
    super.initState();
    compass = AniControl([
      Anim('dir', 0, 360, 45, true),
      Anim('hor', -9.6, 9.6, 20, false),
      Anim('ver', -9.6, 9.6, 20, false),
    ]);

    earth = AniControl([
      Anim('dir', 0, 360, 20, true),
      Anim('lat', -90, 90, 1, false),
      Anim('lon', -180, 180, 1, true),
    ]);

    FlutterCompass.events.listen((angle) {
      compass['dir'].value = angle;
      earth['dir'].value = angle;
    });

    accelerometerEvents.listen((event) {
      compass['hor'].value = -event.x;
      compass['ver'].value = -event.y;
    });

    setLocation(0, 0);
    locate();
  }

  Widget Compass() {
    return GestureDetector(
      onTap: () => setState(() => mode++),
      child: FlareActor("assets/compass.flr",
          animation: 'mode${mode % 2}', controller: compass),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: PageController(viewportFraction: 0.8),
      scrollDirection: Axis.vertical,
      children: [Compass()],
    );
  }
}

class Anim {
  String name;
  double _value = 0, pos = 0, min, max, speed;
  bool endless = false;
  ActorAnimation actor;
  Anim(this.name, this.min, this.max, this.speed, this.endless);
  get value => _value * (max - min) + min;
  set value(double v) => _value = (v - min) / (max - min);
}

class AniControl extends FlareControls {
  List<Anim> items;
  AniControl(this.items);

  @override
  bool advance(FlutterActorArtboard board, double elapsed) {
    super.advance(board, elapsed);
    for (var a in items) {
      if (a.actor == null) continue;
      var d = (a.pos - a._value).abs();
      var m = a.pos > a._value ? -1 : 1;
      if (a.endless && d > 0.5) {
        m = -m;
        d = 1.0 - d;
      }
      var e = elapsed / a.actor.duration * (1 + d * a.speed);
      a.pos = e < d ? (a.pos + e * m) : a._value;
      if (a.endless) a.pos %= 1.0;
      a.actor.apply(a.actor.duration * a.pos, board, 1.0);
    }
    return true;
  }

  @override
  void initialize(FlutterActorArtboard board) {
    super.initialize(board);
    items.forEach((a) => a.actor = board.getAnimation(a.name));
  }

  operator [](String name) {
    for (var a in items) if (a.name == name) return a;
  }
}
