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

// Modo de pantalla: claro, oscuro o el mismo del teléfono
class OpcionModo {
  final String id;
  final String nombre;
  final IconData icono;
  const OpcionModo(this.id, this.nombre, this.icono);
}

const List<OpcionModo> kModos = [
  OpcionModo('claro', 'Claro', Icons.light_mode_outlined),
  OpcionModo('oscuro', 'Oscuro', Icons.dark_mode_outlined),
  OpcionModo('sistema', 'Automático', Icons.brightness_auto_outlined),
];

const String _modoDefecto = 'claro';
const String _acentoDefecto = 'terracota';
const String _fondoDefecto = 'crema';
const String _textoDefecto = 'normal';

// Apariencia del usuario
class Apariencia extends ChangeNotifier with WidgetsBindingObserver {
  Apariencia._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final Apariencia instance = Apariencia._();

  String _modoId = _modoDefecto;
  String _acentoId = _acentoDefecto;
  String _fondoId = _fondoDefecto;
  String _textoId = _textoDefecto;

  StreamSubscription<User?>? _subAuth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subDoc;

  String get modoId => _modoId;
  String get acentoId => _acentoId;
  String get fondoId => _fondoId;
  String get textoId => _textoId;

  // Si el teléfono está en modo oscuro (para el modo Automático)
  @override
  void didChangePlatformBrightness() {
    if (_modoId == 'sistema') notifyListeners();
  }

  bool get oscuro {
    if (_modoId == 'oscuro') return true;
    if (_modoId == 'claro') return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  // Color elegido tal cual (para rellenos)
  Color get acentoBase =>
      kColoresAcento.firstWhere((o) => o.id == _acentoId).color;

  // En oscuro se aclara un poco para que se vea sobre el fondo negro
  Color get acento {
    final base = acentoBase;
    if (!oscuro) return base;
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(hsl.lightness < 0.5 ? 0.5 : hsl.lightness)
        .toColor();
  }

  Color get fondo => oscuro
      ? const Color(0xFF1B1613)
      : kColoresFondo.firstWhere((o) => o.id == _fondoId).color;

  double get escalaTexto =>
      kTamanosTexto.firstWhere((o) => o.id == _textoId).escala;

  // Fondo de la barra lateral: oscuro neutro en modo oscuro,
  // y en claro el acento elegido más oscuro
  Color get fondoMenu {
    if (oscuro) return const Color(0xFF1F1916);
    final hsl = HSLColor.fromColor(acentoBase);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }

  // Paleta común que usan todos los módulos
  Color get superficie => oscuro ? const Color(0xFF26201C) : Colors.white;
  Color get textoOscuro =>
      oscuro ? const Color(0xFFF1E9E3) : const Color(0xFF5A3E36);
  Color get textoClaro =>
      oscuro ? const Color(0xFFBDB0A8) : const Color(0xFF7A6B65);
  Color get textoPrincipal =>
      oscuro ? const Color(0xFFF1E9E3) : const Color(0xFF2E2927);
  Color get hint => oscuro ? Colors.white38 : Colors.black38;
  Color get borde =>
      oscuro ? const Color(0xFF433833) : const Color(0xFFE8DFD8);
  Color get bordeSuave =>
      oscuro ? const Color(0xFF382E2A) : const Color(0xFFEEE7E2);
  Color get fondoInput =>
      oscuro ? const Color(0xFF2E2622) : const Color(0xFFFCFAF7);
  Color get fondoSoloLectura =>
      oscuro ? const Color(0xFF231D1A) : const Color(0xFFF3EEE8);
  Color get acentoSuave =>
      oscuro ? const Color(0xFF362B27) : const Color(0xFFF5EEEE);
  Color get aviso => oscuro ? const Color(0xFF3F3318) : const Color(0xFFFFF1D2);
  Color get indicador =>
      oscuro ? const Color(0xFF4A4219) : const Color(0xFFFCEFA0);
  Color get errorSuave =>
      oscuro ? const Color(0xFF3F2220) : const Color(0xFFFDECEA);
  Color get exitoSuave =>
      oscuro ? const Color(0xFF1F3522) : const Color(0xFFE8F5E9);

  ThemeData _tema(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: acentoBase,
      brightness: brillo,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: brillo == Brightness.dark
          ? esquema.copyWith(primary: acento, surface: superficie)
          : esquema,
      scaffoldBackgroundColor: fondo,
      canvasColor: oscuro ? superficie : null,
      dialogTheme: DialogThemeData(backgroundColor: superficie),
      cardTheme: CardThemeData(color: superficie),
      fontFamily: 'Roboto',
    );
  }

  ThemeData get tema => _tema(oscuro ? Brightness.dark : Brightness.light);

  static String _valido(Iterable<String> ids, Object? valor, String defecto) =>
      (valor is String && ids.contains(valor)) ? valor : defecto;

  // Iniciar (se llama en main)
  void iniciar() {
    _subAuth?.cancel();
    _subAuth = FirebaseAuth.instance.authStateChanges().listen((user) {
      _subDoc?.cancel();
      _subDoc = null;

      if (user == null) {
        _aplicar(_modoDefecto, _acentoDefecto, _fondoDefecto, _textoDefecto);
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
            _valido(kModos.map((o) => o.id), d?['modo'], _modoDefecto),
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

  void _aplicar(String modo, String acento, String fondo, String texto) {
    if (modo == _modoId &&
        acento == _acentoId &&
        fondo == _fondoId &&
        texto == _textoId) {
      return;
    }
    _modoId = modo;
    _acentoId = acento;
    _fondoId = fondo;
    _textoId = texto;
    notifyListeners();
  }

  // Guardar apariencia
  Future<void> guardar({
    String? modo,
    String? acento,
    String? fondo,
    String? texto,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final anterior = (_modoId, _acentoId, _fondoId, _textoId);
    _aplicar(
      modo ?? _modoId,
      acento ?? _acentoId,
      fondo ?? _fondoId,
      texto ?? _textoId,
    );

    try {
      await FirebaseFirestore.instance
          .collection(kColeccionPreferencias)
          .doc(uid)
          .set({
        'modo': _modoId,
        'acento': _acentoId,
        'fondo': _fondoId,
        'texto': _textoId,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _aplicar(anterior.$1, anterior.$2, anterior.$3, anterior.$4);
      rethrow;
    }
  }

  Future<void> restablecer() => guardar(
        modo: _modoDefecto,
        acento: _acentoDefecto,
        fondo: _fondoDefecto,
        texto: _textoDefecto,
      );
}
