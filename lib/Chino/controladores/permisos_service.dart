import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../modelos/usuario_modelo.dart';
import '../vistas/AppDrawer.dart' show ModuloApp;

// Permisos por rol (admin y vendedor)
class Permisos extends ChangeNotifier {
  Permisos._();

  static final Permisos instance = Permisos._();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  String _correo = '';
  Usuario? _perfil;
  bool _cargado = false;
  String? _error;

  bool get cargado => _cargado;

  Usuario? get perfil => _perfil;

  String? get error => _error;

  String get uid => _uid ?? '';
  String get correo => _correo;
  String get nombre => _perfil?.nombre.trim() ?? '';
  String get sucursal => _perfil?.sucursal.trim() ?? '';

  String get estado => _perfil?.estado ?? 'Activo';
  bool get cuentaActiva => estado == 'Activo';

  // Sin perfil cuenta como admin
  bool get esAdmin => _perfil == null || _perfil!.esAdministrador;
  bool get esVendedor => !esAdmin;

  // Escuchar el perfil del usuario
  void iniciar(User user) {
    if (_uid == user.uid && _sub != null) return;
    _cancelar();
    _uid = user.uid;
    _correo = user.email ?? '';
    _perfil = null;
    _cargado = false;
    _error = null;

    _sub = FirebaseFirestore.instance
        .collection(kColeccionUsuarios)
        .doc(user.uid)
        .snapshots()
        .listen(
      (doc) {
        _perfil = doc.exists ? Usuario.fromDoc(doc) : null;
        _cargado = true;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        // Sin perfil legible: rol más restringido
        debugPrint('Permisos: no se pudo leer el perfil: $e');
        _perfil = Usuario(
          id: user.uid,
          codigo: user.uid,
          nombre: '',
          correo: user.email ?? '',
          telefono: '',
          rol: 'Vendedor',
          sucursal: '',
        );
        _cargado = true;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // Dejar de escuchar
  void detener() {
    _cancelar();
    _uid = null;
    _correo = '';
    _perfil = null;
    _cargado = false;
    _error = null;
  }

  void _cancelar() {
    _sub?.cancel();
    _sub = null;
  }

  static String _normSucursal(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^sucursal\s+'), '');

  // Compara sucursales sin el prefijo
  static bool mismaSucursal(String a, String b) =>
      _normSucursal(a) == _normSucursal(b);

  // ¿Es mi sucursal?
  bool esMiSucursal(String otra) =>
      sucursal.isNotEmpty && mismaSucursal(sucursal, otra);

  // ¿Puede abrir el módulo?
  bool puedeVer(ModuloApp modulo) {
    if (!cuentaActiva) return false;
    switch (modulo) {
      case ModuloApp.ventas:
      case ModuloApp.productos:
      case ModuloApp.stock:
      case ModuloApp.materiaPrima:
      case ModuloApp.reportes:
        return true;
      case ModuloApp.usuarios:
      case ModuloApp.sucursales:
      case ModuloApp.auditoria:
        return esAdmin;
    }
  }

  // Ver panel del lobby
  bool get puedeVerLobby => esAdmin;

  // Editar productos y precios
  bool get puedeEditarProductos => esAdmin;

  // Editar ingredientes
  bool get puedeEditarIngredientes => esAdmin;

  // Ajustar stock
  bool puedeAjustarStock(String sucursalDelProducto) =>
      esAdmin || esMiSucursal(sucursalDelProducto);

  // Registrar ventas
  bool get puedeVender => cuentaActiva;

  // Reportes limitados a su sucursal
  bool get reportesLimitados => !esAdmin;

  // Reportes globales
  bool get puedeVerReportesGlobales => esAdmin;

  // Elegir sucursal en la venta
  bool get puedeElegirSucursalDeVenta => esAdmin;

  // Lanza error si no tiene permiso
  void exigir(bool permitido, String accion) {
    if (!permitido) {
      throw StateError('No tienes permiso para $accion.');
    }
  }
}

// Pantalla de acceso restringido
class AccesoRestringido extends StatelessWidget {
  const AccesoRestringido({super.key, this.modulo = 'Este módulo'});

  final String modulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF681015),
        foregroundColor: Colors.white,
        title: Text(modulo),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFFA65021)),
              const SizedBox(height: 16),
              Text(
                'Acceso restringido',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF5A3E36),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$modulo es solo para administradores. '
                'Si necesitas acceso, pídeselo al administrador.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7A6B65)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA65021),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Aviso de falta de permiso
void avisarSinPermiso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
}
