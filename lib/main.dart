import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:neat_tip/bloc/camera.dart';
import 'package:neat_tip/bloc/route_observer.dart';
import 'package:neat_tip/bloc/vehicle_list.dart';
import 'package:neat_tip/db/database.dart';
import 'package:neat_tip/screens/home.dart';
import 'package:neat_tip/screens/introduction.dart';
import 'package:neat_tip/screens/suspend.dart';
import 'package:neat_tip/utils/firebase.dart';
import 'package:neat_tip/utils/route_generator.dart';
import 'package:neat_tip/utils/theme_data.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isCameraGranted = false;
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  late User? user;
  late List<CameraDescription> cameras;
  late NeatTipDatabase database;

  Future<void> initializeComponents() async {
    await AppFirebase.initializeFirebase();
    // await FirebaseAuth.instance.signOut();
    cameras = await availableCameras();
    isCameraGranted = await checkCameraPermission();
    user = FirebaseAuth.instance.currentUser;
    database =
        await $FloorNeatTipDatabase.databaseBuilder('database.db').build();
  }

  Future<void> initializeBloc(BuildContext context) async {
    final blocDB = BlocProvider.of<VehicleListCubit>(context);
    BlocProvider.of<CameraCubit>(context).setCameraList(cameras);
    BlocProvider.of<RouteObserverCubit>(context)
        .setRouteObserver(routeObserver);
    blocDB.initializeDB(database);
    await blocDB.pullDataFromDB();
  }

  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CameraCubit>(
            create: (BuildContext context) => CameraCubit()),
        BlocProvider<RouteObserverCubit>(
            create: (BuildContext context) => RouteObserverCubit()),
        BlocProvider<VehicleListCubit>(
            create: (BuildContext context) => VehicleListCubit()),
      ],
      child: FutureBuilder<void>(
          future: initializeComponents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container();
            }
            return MaterialApp(
              title: 'Flutter Demo',
              navigatorObservers: [routeObserver],
              theme: getThemeData(),
              onGenerateRoute: routeGenerator,
              home: FutureBuilder(
                future: initializeBloc(context),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    FlutterNativeSplash.remove();
                    if (!isCameraGranted) return const Suspend();
                    if (user != null) return const Home();
                    return const Introduction();
                  } else {
                    return Container();
                  }
                },
              ),
            );
          }),
    );
  }
}
