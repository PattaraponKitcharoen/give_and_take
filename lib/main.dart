import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

// Repositories
import 'repositories/auth_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/listing_repository.dart';
import 'repositories/offer_repository.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/wallet_repository.dart';

// Cubits
import 'cubits/auth/auth_cubit.dart';
import 'cubits/auth/auth_state.dart';
import 'cubits/offer/offer_cubit.dart';
import 'cubits/transaction/transaction_cubit.dart';
import 'cubits/review/review_cubit.dart';
import 'cubits/chat/chat_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initNotification();
  runApp(const GiveAndTakeApp());
}

class GiveAndTakeApp extends StatelessWidget {
  const GiveAndTakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => UserRepository()),
        RepositoryProvider(create: (context) => ListingRepository()),
        RepositoryProvider(create: (context) => OfferRepository()),
        RepositoryProvider(create: (context) => TransactionRepository()),
        RepositoryProvider(create: (context) => ReviewRepository()),
        RepositoryProvider(create: (context) => ChatRepository()),
        RepositoryProvider(create: (context) => WalletRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthCubit(
              authRepository: context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => OfferCubit(
              offerRepository: context.read<OfferRepository>(),
              userRepository: context.read<UserRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => TransactionCubit(
              repository: context.read<TransactionRepository>(),
              userRepository: context.read<UserRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ReviewCubit(
              repository: context.read<ReviewRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ChatCubit(
              repository: context.read<ChatRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Give & Take',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008080)),
            useMaterial3: true,
          ),
          home: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state is AuthLoading || state is AuthInitial) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF008080)),
                  ),
                );
              }
              
              if (state is Authenticated) {
                return const MainLayout();
              }
              
              return const LoginScreen(); 
            },
          ),
        ),
      ),
    );
  }
}