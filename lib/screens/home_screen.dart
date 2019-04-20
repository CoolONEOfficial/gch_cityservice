import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gch_cityservice/pages/google_maps_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gch_cityservice/pages/section_list_page.dart';
import 'package:gch_cityservice/services/authentication.dart';
import 'package:gch_cityservice/widget_templates.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

int activeScreen = 0;

enum sections { MyMap, MyList }
enum neededWidget { Section, AppBar }

final List<List<Widget>> screens = [
  [MyMapWidget(), myMapAppBar()],
  [SectionListPage(), myListAppBar()],
];

class HomeScreen extends StatefulWidget {
  HomeScreen({
    Key key,
    this.auth,
    this.userId,
    this.onSignedOut,
  }) : super(key: key);
  final BaseAuth auth;
  final VoidCallback onSignedOut;
  final String userId;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isEmailVerified = false;

  @override
  void initState() {
    _checkEmailVerification().then((result) {
      databaseReference.child("tasks").onValue.listen(
        (event) {
          var _tasks = event?.snapshot?.value;

          Set<MyTask> set = Set<MyTask>();

          for (int taskId = 0; taskId < _tasks.length; taskId++) {
            var task = _tasks[taskId];

            set.add(
              MyTask.defaultClass(
                taskId.toString(),
                LatLng(
                  task["position"]["lat"],
                  task["position"]["lng"],
                ),
                task["name"],
                task["name"],
              ),
            );
          }

          tasksSet = set;

          taskBloc.add(set);
        },
      );
    });

    super.initState();
  }

  Future<bool> _checkEmailVerification() async {
    _isEmailVerified = await widget.auth.isEmailVerified();
    if (!_isEmailVerified) {
      _showVerifyEmailDialog();
    }
    return _isEmailVerified;
  }

  _signOut() async {
    try {
      await widget.auth.signOut();
      widget.onSignedOut();
    } catch (e) {
      print(e);
    }
  }

  void _resentVerifyEmail() {
    widget.auth.sendEmailVerification();
    _showVerifyEmailSentDialog();
  }

  void _showVerifyEmailDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: Text("Verify your account"),
          content: Text("Please verify account in the link sent to email"),
          actions: <Widget>[
            FlatButton(
              child: Text("Resent link"),
              onPressed: () {
                Navigator.of(context).pop();
                _resentVerifyEmail();
              },
            ),
            FlatButton(
              child: Text("Dismiss"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showVerifyEmailSentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: Text("Verify your account"),
          content: Text("Link to verify account has been sent to your email"),
          actions: <Widget>[
            FlatButton(
              child: Text("Dismiss"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  int currentSectionID = sections.MyMap.index;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: screens[currentSectionID][neededWidget.Section.index],
        appBar: screens[currentSectionID][neededWidget.AppBar.index],
        drawer: drawer(context, activeScreen),
      );

  Drawer drawer(BuildContext context, int id) {
    return Drawer(
      child: Column(
        children: <Widget>[
          buildFutureBuilder(
            context,
            future: firebaseAuth.currentUser(),
            builder: (ctx, snapshot) {
              return UserAccountsDrawerHeader(
                  accountName: Text(snapshot.data.displayName ?? "Unknown name"),
                  accountEmail: Text(snapshot.data.email ?? "unknown@mail.com"),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? Colors.blue
                            : Colors.white,
                    child: Image.network(snapshot.data.photoUrl ?? "http://www.sclance.com/pngs/image-placeholder-png/image_placeholder_png_698411.png"),
                  ));
            },
          ),
          ListTile(
            title: Text("Карта"),
            trailing: Icon(Icons.map),
            onTap: () {
              setState(() {
                Navigator.of(context).pop();
                currentSectionID = sections.MyMap.index;
              });
            },
          ),
          ListTile(
            title: Text("Список"),
            trailing: Icon(Icons.list),
            onTap: () {
              setState(() {
                Navigator.of(context).pop();
                currentSectionID = sections.MyList.index;
              });
            },
          ),
          ListTile(
            title: Text("Обращение"),
            trailing: Icon(Icons.add_circle),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            title: Text("Выйти"),
            trailing: Icon(Icons.exit_to_app),
            onTap: () {
              _signOut();
            },
          ),
        ],
      ),
    );
  }
}

final databaseReference = FirebaseDatabase.instance.reference();

class MyTask {
  MyTask();

  MyTask.defaultClass(this.id, this.position, this.title, this.snippet);

  String title = 'default title';
  String snippet = 'default snippet';
  String id = '1234567890';

  LatLng position = LatLng(56.327752241668215, 44.00208346545696);

  Marker toMarker() {
    var myDescriptor =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

    if (this is GoodTask) {
      myDescriptor =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (this is BadTask) {
      myDescriptor = BitmapDescriptor.defaultMarker;
    }

    return Marker(
      markerId: MarkerId(this.id),
      position: this.position,
      onTap: () => onMarkerTap(this),
      icon: myDescriptor,
    );
  }
}

Set<MyTask> tasksSet = Set();
final taskBloc = StreamController<void>.broadcast();