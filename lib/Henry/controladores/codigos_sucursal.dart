import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/sucursal_modelo.dart';

// Códigos con prefijo por sucursal: N001 (Norte), S001 (Sur), NE001 (Noroeste)...
// Cada sucursal tiene su propio prefijo, así dos sucursales nunca repiten
// el código de una venta, producto, ingrediente o usuario.
class CodigosSucursal {
  CodigosSucursal._();

  static const int maxPrefijo = 4;

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceFirst(RegExp(r'^sucursal\s+'), '');

  // Solo letras A-Z en mayúscula
  static String limpiarPrefijo(String t) =>
      t.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

  static bool prefijoValido(String p) =>
      RegExp('^[A-Z]{1,$maxPrefijo}\$').hasMatch(p);

  static const String _conAcento = 'ÁÀÄÂáàäâÉÈËÊéèëêÍÌÏÎíìïîÓÒÖÔóòöôÚÙÜÛúùüûÑñ';
  static const String _sinAcento = 'AAAAaaaaEEEEeeeeIIIIiiiiOOOOooooUUUUuuuuNn';

  // Letras del nombre en mayúscula, sin acentos ni la palabra "Sucursal"
  static String _letras(String nombre) {
    final sb = StringBuffer();
    final n = nombre.trim().replaceFirst(
          RegExp(r'^sucursal\s+', caseSensitive: false),
          '',
        );
    for (final c in n.split('')) {
      final i = _conAcento.indexOf(c);
      sb.write(i >= 0 ? _sinAcento[i] : c);
    }
    return limpiarPrefijo(sb.toString());
  }

  // Prefijo sugerido para un nombre: la primera letra y, si ya está en uso,
  // las dos primeras, y así. Ej. Sur -> S, Norte -> N, Noroeste -> NO
  static String sugerir(String nombre, Set<String> usados) {
    final l = _letras(nombre);
    if (l.isEmpty) return '';
    for (var n = 1; n <= math.min(l.length, maxPrefijo); n++) {
      final c = l.substring(0, n);
      if (!usados.contains(c)) return c;
    }
    // Todas las variantes ocupadas: cambia la última letra
    final base = l.substring(0, math.min(l.length, maxPrefijo - 1));
    for (final x in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      if (!usados.contains('$base$x')) return '$base$x';
    }
    return l.substring(0, 1);
  }

  // Prefijo de cada sucursal (id -> prefijo). Usa el guardado y, si falta o
  // se repite, calcula uno estable según el orden de código de las sucursales.
  static Map<String, String> calcular(List<Sucursal> sucursales) {
    final orden = [...sucursales]..sort((a, b) {
        final c = a.codigo.compareTo(b.codigo);
        return c != 0 ? c : a.nombre.compareTo(b.nombre);
      });
    final res = <String, String>{};
    final usados = <String>{};
    for (final s in orden) {
      final p = limpiarPrefijo(s.prefijo);
      if (prefijoValido(p) && !usados.contains(p)) {
        res[s.id] = p;
        usados.add(p);
      }
    }
    for (final s in orden) {
      if (res.containsKey(s.id)) continue;
      final p = sugerir(s.nombre, usados);
      if (p.isEmpty) continue;
      res[s.id] = p;
      usados.add(p);
    }
    return res;
  }

  // Todas las sucursales con su prefijo
  static Future<Map<String, String>> prefijosActuales(
    FirebaseFirestore db,
  ) async {
    final snap = await db.collection(kColeccionSucursales).get();
    return calcular(snap.docs.map(Sucursal.fromDoc).toList());
  }

  // Prefijo de la sucursal con ese nombre (null si no existe)
  static Future<String?> prefijoDe(
    FirebaseFirestore db,
    String nombreSucursal,
  ) async {
    final buscado = _norm(nombreSucursal);
    if (buscado.isEmpty) return null;
    final snap = await db.collection(kColeccionSucursales).get();
    final sucursales = snap.docs.map(Sucursal.fromDoc).toList();
    final prefijos = calcular(sucursales);
    for (final s in sucursales) {
      if (_norm(s.nombre) == buscado) return prefijos[s.id];
    }
    return null;
  }

  // N + 1 -> N001
  static String formatear(String prefijo, int numero) =>
      '$prefijo${numero.toString().padLeft(3, '0')}';

  // Número de un código con ese prefijo (null si no corresponde).
  // "N004" con prefijo N -> 4; "NE004" con prefijo N -> null
  static int? numeroDe(String codigo, String prefijo) {
    final m =
        RegExp('^${RegExp.escape(prefijo)}(\\d+)\$').firstMatch(codigo.trim());
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  // Número más alto que ya existe con ese prefijo en la colección.
  // [campo] null = el código es el id del documento.
  static Future<int> _maximo({
    required FirebaseFirestore db,
    required String coleccion,
    required String prefijo,
    String? campo,
  }) async {
    final Object clave = campo ?? FieldPath.documentId;
    final snap = await db
        .collection(coleccion)
        .where(clave, isGreaterThanOrEqualTo: prefijo)
        .where(clave, isLessThan: '$prefijo\uf8ff')
        .get();
    var maximo = 0;
    for (final d in snap.docs) {
      final codigo = campo == null ? d.id : (d.data()[campo] ?? '').toString();
      final n = numeroDe(codigo, prefijo);
      if (n != null && n > maximo) maximo = n;
    }
    return maximo;
  }

  // Siguiente código libre (solo lectura: no lo reserva)
  static Future<String> siguiente({
    required FirebaseFirestore db,
    required String coleccion,
    required String prefijo,
    String? campo,
  }) async {
    final m = await _maximo(
        db: db, coleccion: coleccion, prefijo: prefijo, campo: campo);
    return formatear(prefijo, m + 1);
  }

  // Colección con un contador por sucursal y tipo (ej. ventas_N)
  static const String coleccionContadores = 'contadores';

  // Reserva el siguiente código con un contador atómico: dos personas que
  // guardan a la vez en la misma sucursal reciben números distintos.
  // El número reservado no se vuelve a dar aunque el guardado falle o se
  // elimine el registro (puede quedar un hueco, nunca un repetido).
  static Future<String> reservar({
    required FirebaseFirestore db,
    required String coleccion,
    required String prefijo,
    String? campo,
  }) async {
    // Punto de partida: lo que ya existe (datos anteriores al contador)
    final base = await _maximo(
        db: db, coleccion: coleccion, prefijo: prefijo, campo: campo);
    final ref =
        db.collection(coleccionContadores).doc('${coleccion}_$prefijo');
    try {
      final numero = await db.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        final v = snap.data()?['ultimo'];
        final ultimo = v is num ? v.toInt() : 0;
        final n = (ultimo > base ? ultimo : base) + 1;
        tx.set(ref, {
          'ultimo': n,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
        return n;
      });
      return formatear(prefijo, numero);
    } on FirebaseException catch (e) {
      // Reglas de Firestore sin publicar (colección contadores): se usa el
      // siguiente número libre, sin la garantía del contador
      if (e.code == 'permission-denied') return formatear(prefijo, base + 1);
      rethrow;
    }
  }

  // Igual, pero a partir de una lista que ya se tiene en pantalla
  static String siguienteDeLista(Iterable<String> codigos, String prefijo) {
    var maximo = 0;
    for (final c in codigos) {
      final n = numeroDe(c, prefijo);
      if (n != null && n > maximo) maximo = n;
    }
    return formatear(prefijo, maximo + 1);
  }
}
