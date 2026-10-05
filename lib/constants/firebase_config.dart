import 'package:cloud_functions/cloud_functions.dart';

/// Region the Cloud Functions are deployed to — must match
/// `setGlobalOptions({ region })` in functions/index.js. It's the same
/// region as the Firestore database, so the functions' reads stay local.
const String kFunctionsRegion = 'asia-southeast1';

FirebaseFunctions appFunctions() =>
    FirebaseFunctions.instanceFor(region: kFunctionsRegion);
