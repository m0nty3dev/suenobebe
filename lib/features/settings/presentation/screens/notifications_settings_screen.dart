import 'package:flutter/material.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Las notificaciones de inactividad se envían si llevas '
              'más de 3 horas sin registrar nada durante el día.',
            ),
            SizedBox(height: 16),
            Text('Sin interrupciones entre las 22:00 y las 8:00.'),
            SizedBox(height: 24),
            Text('Configuración granular disponible próximamente.'),
          ],
        ),
      ),
    );
  }
}
