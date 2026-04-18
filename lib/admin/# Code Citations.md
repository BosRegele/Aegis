# Code Citations

## License: unknown
https://github.com/hngx-org/joke-ai-app/blob/5a59755ef531009c727e6258789b9581fd00ab81/lib/main.dart

```
# Înțeleg ce vrei! 

Vrei să ai o **card alb rotunjit în stânga** pe care să afișezi pe ce rol ești, similar cu `admin_schedules`. 

Iată cum să implementezi asta în `main.dart` și în paginile de admin:

````dart
// filepath: d:\flutterapps\firster\lib\main.dart
// ...existing code...

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _buildHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString();
    final username = (data['username'] ?? '').toString();

    AppSession.setUser(
      uidValue: user.uid,
      usernameValue: username,
      roleValue: role,
    );

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const LoginPageFirestore();
          }

          return FutureBuilder<Widget>(
            future: _buil
```


## License: unknown
https://github.com/hngx-org/joke-ai-app/blob/5a59755ef531009c727e6258789b9581fd00ab81/lib/main.dart

```
# Înțeleg ce vrei! 

Vrei să ai o **card alb rotunjit în stânga** pe care să afișezi pe ce rol ești, similar cu `admin_schedules`. 

Iată cum să implementezi asta în `main.dart` și în paginile de admin:

````dart
// filepath: d:\flutterapps\firster\lib\main.dart
// ...existing code...

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _buildHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString();
    final username = (data['username'] ?? '').toString();

    AppSession.setUser(
      uidValue: user.uid,
      usernameValue: username,
      roleValue: role,
    );

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const LoginPageFirestore();
          }

          return FutureBuilder<Widget>(
            future: _buil
```


## License: unknown
https://github.com/hngx-org/joke-ai-app/blob/5a59755ef531009c727e6258789b9581fd00ab81/lib/main.dart

```
# Înțeleg ce vrei! 

Vrei să ai o **card alb rotunjit în stânga** pe care să afișezi pe ce rol ești, similar cu `admin_schedules`. 

Iată cum să implementezi asta în `main.dart` și în paginile de admin:

````dart
// filepath: d:\flutterapps\firster\lib\main.dart
// ...existing code...

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _buildHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString();
    final username = (data['username'] ?? '').toString();

    AppSession.setUser(
      uidValue: user.uid,
      usernameValue: username,
      roleValue: role,
    );

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const LoginPageFirestore();
          }

          return FutureBuilder<Widget>(
            future: _buil
```


## License: unknown
https://github.com/hngx-org/joke-ai-app/blob/5a59755ef531009c727e6258789b9581fd00ab81/lib/main.dart

```
# Înțeleg ce vrei! 

Vrei să ai o **card alb rotunjit în stânga** pe care să afișezi pe ce rol ești, similar cu `admin_schedules`. 

Iată cum să implementezi asta în `main.dart` și în paginile de admin:

````dart
// filepath: d:\flutterapps\firster\lib\main.dart
// ...existing code...

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _buildHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString();
    final username = (data['username'] ?? '').toString();

    AppSession.setUser(
      uidValue: user.uid,
      usernameValue: username,
      roleValue: role,
    );

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const LoginPageFirestore();
          }

          return FutureBuilder<Widget>(
            future: _buil
```

