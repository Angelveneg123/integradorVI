import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Colección de preferencias
const String kColeccionPreferencias = 'preferencias';

class OpcionColor {
  final String id;
  final String nombre;
  final Color color;
  const OpcionColor(this.id, this.nombre, this.color);
}

class OpcionTexto {
  final String id;
  final String nombre;
  final double escala;
  const OpcionTexto(this.id, this.nombre, this.escala);
}

const List<OpcionColor> kColoresAcento = [
  OpcionColor('terracota', 'Terracota', Color(0xFFA65021)),
  OpcionColor('vino', 'Vino', Color(0xFF8D141B)),
  OpcionColor('naranja', 'Naranja', Color(0xFFD27A0A)),
  OpcionColor('verde', 'Verde', Color(0xFF2E7D32)),
  OpcionColor('azul', 'Azul', Color(0xFF1565C0)),
  OpcionColor('morado', 'Morado', Color(0xFF6A1B9A)),
];

const List<OpcionColor> kColoresFondo = [
  OpcionColor('crema', 'Crema', Color(0xFFF9F6EF)),
  OpcionColor('blanco', 'Blanco', Color(0xFFFFFFFF)),
  OpcionColor('gris', 'Gris', Color(0xFFF1F1F1)),
  OpcionColor('rosado', 'Rosado', Color(0xFFFBEFEF)),
  OpcionColor('menta', 'Menta', Color(0xFFEEF6EE)),
];

const List<OpcionTexto> kTamanosTexto = [
  OpcionTexto('pequeno', 'Pequeño', 0.9),
  OpcionTexto('normal', 'Normal', 1.0),
  OpcionTexto('grande', 'Grande', 1.15),
  OpcionTexto('muy_grande', 'Muy grande', 1.3),
];

const String _acentoDefecto = 'terracota';
const String _fondoDefecto = 'crema';
const String _textoDefecto = 'normal';

// Apariencia del usuario
class Apariencia extends ChangeNotifier {
  Apariencia._();
  static final Apariencia instance = Apariencia._();

  String _acentoId = _acentoDefecto;
  String _fondoId = _fondoDefecto;
  String _textoId = _textoDefecto;

  StreamSubscription<User?>? _subAuth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subDoc;

  String get acentoId => _acentoId;
  String get fondoId => _fondoId;
  String get textoId => _textoId;

  Color get acento =>
      kColoresAcento.firstWhere((o) => o.id == _acentoId).color;
  Color get fondo => kColoresFondo.firstWhere((o) => o.id == _fondoId).color;
  double get escalaTexto =>
      kTamanosTexto.firstWhere((o) => o.id == _textoId).escala;

  ThemeData get tema => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: acento),
        scaffoldBackgroundColor: fondo,
        fontFamily: 'Roboto',
      );

  static String _valido(Iterable<String> ids, Object? valor, String defecto) =>
      (valor is String && ids.contains(valor)) ? valor : defecto;

  // Iniciar (se llama en main)
  void iniciar() {
    _subAuth?.cancel();
    _subAuth = FirebaseAuth.instance.authStateChanges().listen((user) {
      _subDoc?.cancel();
      _subDoc = null;

      if (user == null) {
        _aplicar(_acentoDefecto, _fondoDefecto, _textoDefecto);
        return;
      }
      _subDoc = FirebaseFirestore.instance
          .collection(kColeccionPreferencias)
          .doc(user.uid)
          .snapshots()
          .listen(
        (doc) {
          final d = doc.data();
          _aplicar(
            _valido(kColoresAcento.map((o) => o.id), d?['acento'], _acentoDefecto),
            _valido(kColoresFondo.map((o) => o.id), d?['fondo'], _fondoDefecto),
            _valido(kTamanosTexto.map((o) => o.id), d?['texto'], _textoDefecto),
          );
        },
        onError: (Object e) =>
            debugPrint('No se pudieron leer las preferencias: $e'),
      );
    });
  }

  void _aplicar(String acento, String fondo, String texto) {
    if (acento == _acentoId && fondo == _fondoId && texto == _textoId) return;
    _acentoId = acento;
    _fondoId = fondo;
    _textoId = texto;
    notifyListeners();
  }

  // Guardar apariencia
  Future<void> guardar({String? acento, String? fondo, String? texto}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final anterior = (_acentoId, _fondoId, _textoId);
    _aplicar(acento ?? _acentoId, fondo ?? _fondoId, texto ?? _textoId);

    try {
      await FirebaseFirestore.instance
          .collection(kColeccionPreferencias)
          .doc(uid)
          .set({
        'acento': _acentoId,
        'fondo': _fondoId,
        'texto': _textoId,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _aplicar(anterior.$1, anterior.$2, anterior.$3);
      rethrow;
    }
  }

  Future<void> restablecer() => guardar(
        acento: _acentoDefecto,
        fondo: _fondoDefecto,
        texto: _textoDefecto,
      );
}
