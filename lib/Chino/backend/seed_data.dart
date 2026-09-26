import 'package:cloud_firestore/cloud_firestore.dart';

import 'evento_auditoria_modelo.dart';
import 'producto_modelo.dart';
import 'venta_modelo.dart';

/// Llena Firestore con datos de ejemplo para poder probar Stock, Reportes
/// y Auditoria SIN necesitar todavía los módulos de Productos y Ventas
/// terminados.
///
/// Esto simula lo que esos módulos escribirían: crea documentos en
/// `productos` (con la forma del CRUD del Figma), en `ventas`
/// (para el reporte "Ventas por periodo") y en `auditoria`
/// (para el módulo de Auditoria y el reporte "Auditoría de actividad").
///
/// Es seguro correrlo varias veces: usa IDs fijos para `productos`
/// (upsert/merge) y sólo agrega documentos nuevos en `ventas`/`auditoria`
/// si la colección todavía está vacía.
Future<void> sembrarDatosDePrueba({FirebaseFirestore? firestore}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  await _sembrarProductos(db);
  await _sembrarVentas(db);
  await _sembrarAuditoria(db);
}

Future<void> _sembrarProductos(FirebaseFirestore db) async {
  final coleccion = db.collection(kColeccionProductos);

  final productos = <Producto>[
    Producto(
      id: 'P001',
      codigo: 'P001',
      nombre: 'Donas de chocolate',
      categoria: 'Repostería',
      precio: 29.00,
      stock: 37,
      stockMinimo: 10,
      sucursal: 'Norte',
      estado: 'Activo',
      ingredientes: const [
        Ingrediente(nombre: 'Harina', cantidad: '100 gm'),
        Ingrediente(nombre: 'Agua', cantidad: '20 ml'),
        Ingrediente(nombre: 'Sal', cantidad: '5 gm'),
      ],
    ),
    Producto(
      id: 'P002',
      codigo: 'P002',
      nombre: 'Pan Integral',
      categoria: 'Pan',
      precio: 17.00,
      stock: 15,
      stockMinimo: 10,
      sucursal: 'Centro',
      estado: 'Activo',
      ingredientes: const [
        Ingrediente(nombre: 'Harina integral', cantidad: '150 gm'),
        Ingrediente(nombre: 'Levadura', cantidad: '5 gm'),
      ],
    ),
    Producto(
      id: 'P003',
      codigo: 'P003',
      nombre: 'Orejita',
      categoria: 'Repostería',
      precio: 25.00,
      stock: 0,
      stockMinimo: 8,
      sucursal: 'Norte',
      estado: 'Inactivo',
    ),
    Producto(
      id: 'P004',
      codigo: 'P004',
      nombre: 'Pan Lagarto',
      categoria: 'Pan',
      precio: 35.00,
      stock: 10,
      stockMinimo: 10,
      sucursal: 'Centro',
      estado: 'Activo',
    ),
    Producto(
      id: 'P005',
      codigo: 'P005',
      nombre: 'Baguette',
      categoria: 'Pan',
      precio: 17.00,
      stock: 60,
      stockMinimo: 15,
      sucursal: 'Centro',
      estado: 'Activo',
    ),
  ];

  final batch = db.batch();
  for (final producto in productos) {
    batch.set(coleccion.doc(producto.id), producto.toMap(), SetOptions(merge: true));
  }
  await batch.commit();
}

Future<void> _sembrarVentas(FirebaseFirestore db) async {
  final coleccion = db.collection(kColeccionVentas);
  final existentes = await coleccion.limit(1).get();
  if (existentes.docs.isNotEmpty) return; // ya hay datos, no dupliques

  final ahora = DateTime.now();
  final ventas = <Venta>[
    Venta(
      id: '',
      fecha: ahora.subtract(const Duration(days: 12)),
      sucursal: 'Centro',
      cliente: 'Consumidor final',
      metodoPago: 'Efectivo',
      total: 6800.00,
      items: const [
        ItemVenta(nombre: 'Pan Integral', cantidad: 4500, precioUnitario: 1.2),
        ItemVenta(nombre: 'Baguette', cantidad: 500, precioUnitario: 1.6),
      ],
    ),
    Venta(
      id: '',
      fecha: ahora.subtract(const Duration(days: 12)),
      sucursal: 'Centro',
      cliente: 'Consumidor final',
      metodoPago: 'Tarjeta',
      total: 1400.00,
      items: const [
        ItemVenta(nombre: 'Baguette', cantidad: 500, precioUnitario: 2.8),
      ],
    ),
    Venta(
      id: '',
      fecha: ahora.subtract(const Duration(days: 17)),
      sucursal: 'Norte',
      cliente: 'Consumidor final',
      metodoPago: 'Efectivo',
      total: 3975.00,
      items: const [
        ItemVenta(nombre: 'Pan Francés', cantidad: 3000, precioUnitario: 1.325),
      ],
    ),
  ];

  final batch = db.batch();
  for (final venta in ventas) {
    batch.set(coleccion.doc(), venta.toMap());
  }
  await batch.commit();
}

Future<void> _sembrarAuditoria(FirebaseFirestore db) async {
  final coleccion = db.collection(kColeccionAuditoria);
  final existentes = await coleccion.limit(1).get();
  if (existentes.docs.isNotEmpty) return; // ya hay datos, no dupliques

  final ahora = DateTime.now();
  final eventos = <Map<String, dynamic>>[
    {
      'titulo': 'Acceso',
      'tipo': TipoEvento.ingresar.name,
      'descripcion': 'Inicio de sesión en el sistema',
      'autor': 'Juan Pérez',
      'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 9))),
      'modulo': 'Accesos',
      'idReferencia': 'A-00087',
      'productos': const [],
      'datosAdicionales': [
        CampoInfo('Usuario', 'Juan Pérez').toMap(),
        CampoInfo('Correo', 'juan.perez@panaderiaromero.com').toMap(),
        CampoInfo('Rol', 'Administrador').toMap(),
        CampoInfo('Dispositivo', 'Chrome · Windows').toMap(),
        CampoInfo('Dirección IP', '190.104.22.18').toMap(),
      ],
    },
    {
      'titulo': 'Ventas',
      'tipo': TipoEvento.eliminar.name,
      'descripcion': 'Eliminó la venta #V-00123',
      'autor': 'Juan Pérez',
      'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 17))),
      'modulo': 'Ventas',
      'idReferencia': 'V-00123',
      'productos': [
        const ProductoMovimiento(nombre: 'Pan Francés', cantidad: 3000).toMap(),
        const ProductoMovimiento(nombre: 'Croissant', cantidad: 450).toMap(),
      ],
      'datosAdicionales': [
        CampoInfo('Motivo de eliminación', 'Registro duplicado').toMap(),
        CampoInfo('Monto total', 'C\$ 5,175.00').toMap(),
      ],
    },
    {
      'titulo': 'Ventas',
      'tipo': TipoEvento.crear.name,
      'descripcion': 'Se registró la venta #V-00124',
      'autor': 'Juan Pérez',
      'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 12))),
      'modulo': 'Ventas',
      'idReferencia': 'V-00124',
      'productos': [
        const ProductoMovimiento(nombre: 'Pan Integral', cantidad: 4500).toMap(),
        const ProductoMovimiento(nombre: 'Baguette', cantidad: 500).toMap(),
      ],
      'datosAdicionales': [
        CampoInfo('Cliente', 'Consumidor final').toMap(),
        CampoInfo('Método de pago', 'Efectivo').toMap(),
        CampoInfo('Monto total', 'C\$ 6,800.00').toMap(),
      ],
    },
    {
      'titulo': 'Stock',
      'tipo': TipoEvento.editar.name,
      'descripcion': 'Ajuste de inventario (entrada de stock)',
      'autor': 'Juan Pérez',
      'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 8))),
      'modulo': 'Stock',
      'idReferencia': 'S-00210',
      'productos': [
        const ProductoMovimiento(
          nombre: 'Croissant',
          cantidad: 10,
          detalle: 'Stock: 45 → 55 · Motivo: Producción',
        ).toMap(),
      ],
      'datosAdicionales': const [],
    },
    {
      'titulo': 'Usuarios',
      'tipo': TipoEvento.crear.name,
      'descripcion': 'Se creó un nuevo usuario en el sistema',
      'autor': 'Juan Pérez',
      'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 6))),
      'modulo': 'Usuarios',
      'idReferencia': 'U-00045',
      'productos': const [],
      'datosAdicionales': [
        CampoInfo('Nombre', 'María López').toMap(),
        CampoInfo('Correo', 'maria.lopez@panaderiaromero.com').toMap(),
        CampoInfo('Rol asignado', 'Vendedor').toMap(),
      ],
    },
  ];

  final batch = db.batch();
  for (final evento in eventos) {
    batch.set(coleccion.doc(), evento);
  }
  await batch.commit();
}
