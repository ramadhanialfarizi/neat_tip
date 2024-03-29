import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:neat_tip/bloc/camera.dart';
import 'package:neat_tip/bloc/route_observer.dart';
import 'package:neat_tip/bloc/transaction_list.dart';
import 'package:neat_tip/bloc/vehicle_list.dart';
import 'package:neat_tip/db/database.dart';
import 'package:neat_tip/screens/home.dart';
import 'package:neat_tip/screens/introduction.dart';
import 'package:neat_tip/screens/loading_window.dart';
import 'package:neat_tip/screens/permission_window.dart';
import 'package:neat_tip/utils/firebase.dart';
import 'package:neat_tip/utils/route_generator.dart';
import 'package:neat_tip/utils/theme_data.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isNeedPermission = false;
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  late User? user;
  late List<CameraDescription> cameras;
  late NeatTipDatabase database;
  late VehicleListCubit vehicleListCubit;
  late TransactionsListCubit transactionsListCubit;
  late CameraCubit cameraCubit;
  late RouteObserverCubit routeObserverCubit;

  Future<void> initializeComponents() async {
    // log('panggil');
    await AppFirebase.initializeFirebase();
    // await FirebaseAuth.instance.signOut();
    isNeedPermission = await checkPermission();
    user = FirebaseAuth.instance.currentUser;
    database =
        await $FloorNeatTipDatabase.databaseBuilder('database.db').build();

    vehicleListCubit.initializeDB(database);
    vehicleListCubit.pullDataFromDB();

    transactionsListCubit.initializeDB(database);
    transactionsListCubit.pullDataFromDB();

    cameras = await availableCameras();
    cameraCubit.setCameraList(cameras);
    routeObserverCubit.setRouteObserver(routeObserver);
  }

  Future<bool> checkPermission() async {
    bool isAllAllowed = true;

    for (var service in serviceList) {
      final Permission permission = service['type'];
      final status = await permission.status;
      if (!status.isGranted) isAllAllowed = false;
    }
    return isAllAllowed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    vehicleListCubit = VehicleListCubit();
    transactionsListCubit = TransactionsListCubit();
    cameraCubit = CameraCubit();
    routeObserverCubit = RouteObserverCubit();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: initializeComponents(),
        builder: (context, snapshot) {
          return MultiBlocProvider(
              providers: [
                BlocProvider<CameraCubit>(
                    create: (BuildContext context) => cameraCubit),
                BlocProvider<RouteObserverCubit>(
                    create: (BuildContext context) => routeObserverCubit),
                BlocProvider<VehicleListCubit>(
                    create: (BuildContext context) => vehicleListCubit),
                BlocProvider<TransactionsListCubit>(
                    create: (BuildContext context) => transactionsListCubit),
              ],
              child: MaterialApp(
                title: 'Neat Tip',
                navigatorObservers: [routeObserver],
                theme: getThemeData(),
                onGenerateRoute: routeGenerator,
                home: () {
                  // FlutterNativeSplash.remove();
                  // return LoadingWindow();
                  if (snapshot.connectionState != ConnectionState.done) {
                    //  FlutterNativeSplash.remove();
                    return const LoadingWindow();
                  } else {
                    FlutterNativeSplash.remove();
                    if (user == null) {
                      return const Introduction();
                    } else if (!isNeedPermission) {
                      return Builder(builder: (context) {
                        return PermissionWindow(
                          onAllowedAll: () {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/home', (route) => false);
                          },
                        );
                      });
                    }
                    return const Home();
                  }
                }(),
              ));
        });
  }
}
