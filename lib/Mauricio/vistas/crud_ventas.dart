import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../firebase_options.dart';
import '../modelos/FuncionVenta.dart';
import '../controladores/ConeccionFirebase.dart';
import '../controladores/VentasStock.dart';
import '../../Henry/controladores/codigos_sucursal.dart';
import '../../Chino/vistas/AppDrawer.dart';
import '../../Chino/controladores/auditoria_service.dart';
import '../../Chino/modelos/evento_auditoria_modelo.dart'
    show TipoEvento, ProductoMovimiento, CampoInfo;
import '../../Henry/modelos/sucursal_modelo.dart' show etiquetaSucursal;
import '../../Chino/controladores/permisos_service.dart';
import '../../Chino/controladores/apariencia_service.dart';
import '../../Chino/vistas/filtros_comunes.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;
Color get _fondoSoloLectura => Apariencia.instance.fondoSoloLectura;
const Color _verde = Color(0xFF1F7A3D);
const Color _rojo = Color(0xFFB3261E);

const List<String> _kEstados = ['Activo', 'Inactivo'];

InputDecoration _decoracionCampo({String? hint, bool soloLectura = false}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Apariencia.instance.hint, fontSize: 14),
    filled: true,
    fillColor: soloLectura ? _fondoSoloLectura : _fondoInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _colorBorde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _colorAcento),
    ),
  );
}

BoxDecoration get _decoracionTarjeta => BoxDecoration(
  color: Apariencia.instance.superficie,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _colorBorde),
);

String _dinero(double valor) => 'C\$ ${valor.toStringAsFixed(2)}';

String _numero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

double _totalVenta(CRUDVentas v) => v.total;

// Nombre de sucursal normalizado
String _norm(String s) =>
    s.trim().toLowerCase().replaceFirst(RegExp(r'^sucursal\s+'), '');

Widget _etiqueta(String texto) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(texto, style: TextStyle(fontSize: 12, color: _textoClaro)),
);

Widget _tituloSeccion(String texto) => Text(
  texto,
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: _textoOscuro,
  ),
);

// Tema del calendario y reloj
Widget _temaPicker(BuildContext context, Widget? child) => Theme(
  data: Theme.of(context).copyWith(
    colorScheme: Theme.of(context).colorScheme.copyWith(primary: _colorAcento),
  ),
  child: child!,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const VentasApp());
}

class VentasApp extends StatelessWidget {
  const VentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Venta',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF9F6EF),
        colorScheme: ColorScheme.fromSeed(seedColor: _colorAcento),
      ),
      home: const VentasScreen(),
    );
  }
}

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key, this.abrirNuevaVenta = false});

  // Abre directo el formulario de nueva venta
  final bool abrirNuevaVenta;

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  // Llave del menú lateral
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // FIRESTORE
  List<CRUDVentas> Listventas = [];
  bool cargandoVenta = true;

  // Suscripciones en tiempo real
  StreamSubscription<List<CRUDVentas>>? _subVentas;
  StreamSubscription<List<ProductList>>? _subProductos;
  bool _primeraCargaVentas = true;
  // Evita guardar dos veces si se toca Guardar con internet lento
  bool _guardandoVenta = false;
  // Evita repetir eliminar / anular / reactivar con toques seguidos
  bool _procesandoVenta = false;
  // Id de la venta nueva: el mismo en todos los intentos de guardado
  String? _ventaIdNueva;
  // Código reservado para esa venta: se reutiliza si se reintenta el guardado
  String? _codigoVentaReservado;
  String? _prefijoVentaReservado;

  @override
  void initState() {
    super.initState();
    _escucharVentas();
    _escucharProductos();
  }

  void _escucharVentas() {
    _subVentas?.cancel();
    _subVentas = streamVentasDb().listen(
      (todas) {
        // El vendedor solo ve su sucursal
        final permisos = Permisos.instance;
        final lista = permisos.esAdmin
            ? todas
            : todas.where((v) => permisos.esMiSucursal(v.sucursalU)).toList();
        if (!mounted) return;
        setState(() {
          Listventas = lista;
          cargandoVenta = false;
          // Actualiza la venta abierta
          final id = ventaSeleccionado?.id;
          if (id != null) {
            final i = lista.indexWhere((v) => v.id == id);
            if (i != -1) ventaSeleccionado = lista[i];
          }
        });
        // Espera la primera carga para el código
        if (_primeraCargaVentas) {
          _primeraCargaVentas = false;
          if (widget.abrirNuevaVenta) nuevoProducto();
        }
      },
      onError: (e) {
        debugPrint('ERROR AL ESCUCHAR VENTAS: $e');
        if (!mounted) return;
        setState(() => cargandoVenta = false);
      },
    );
  }

  void _escucharProductos() {
    _subProductos?.cancel();
    _subProductos = streamProductosDb().listen(
      (prods) {
        if (!mounted) return;
        setState(() {
          listaProductos = prods;
          errorProductos = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => errorProductos = e.toString());
      },
    );
  }

  CRUDVentas? ventaSeleccionado;
  String textoBusqueda = '';

  // Filtros desplegables
  String filtroSucursal = '';
  String filtroEstado = '';
  DateTime? filtroDesde;
  DateTime? filtroHasta;

  // CONTROLADORES
  final CodigoVentaController = TextEditingController();
  final sucursalController = TextEditingController();
  final HoraFechaVentaController = TextEditingController();
  final EstadoVentaController = TextEditingController();

  String estadoSeleccionado = 'Activo';
  String vista = 'lista';
  List<ProductList> productosTemp = [];

  // Sucursales activas
  List<String> listaSucursales = [];
  bool cargandoSucursales = false;

  // Error al leer los productos
  String? errorProductos;

  double get _totalProductosTemp =>
      productosTemp.fold<double>(0, (suma, p) => suma + p.precio * p.cantidad);

  //FILTRAR Ventas////////////////////////////////////////////////////////////////
  List<CRUDVentas> get ventasFiltrados {
    final listaFiltrada = Listventas.where((ventas) {
      final coincideBusqueda = ventas.codigoV.toLowerCase().contains(
        textoBusqueda.toLowerCase(),
      );

      final coincideSucursal = filtroSucursal.isEmpty ||
          _norm(ventas.sucursalU) == _norm(filtroSucursal);
      final coincideEstado =
          filtroEstado.isEmpty || ventas.estado == filtroEstado;
      final coincideFecha = fechaEnRango(
        DateTime.tryParse(ventas.fecha),
        filtroDesde,
        filtroHasta,
      );
      return coincideBusqueda &&
          coincideSucursal &&
          coincideEstado &&
          coincideFecha;
    }).toList();

    // Ordenar de la fecha más reciente a la más antigua
    listaFiltrada.sort((a, b) {
      final DateTime? fechaA = DateTime.tryParse(a.fecha);
      final DateTime? fechaB = DateTime.tryParse(b.fecha);
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      return fechaB.compareTo(fechaA);
    });

    return listaFiltrada;
  }

  // Sucursales para el filtro: las activas más las que ya tienen ventas
  Map<String, String> get _opcionesSucursal {
    final nombres = <String>[...listaSucursales];
    for (final v in Listventas) {
      final n = v.sucursalU.trim();
      if (n.isNotEmpty && !nombres.any((x) => _norm(x) == _norm(n))) {
        nombres.add(n);
      }
    }
    return {
      '': 'Todas las sucursales',
      for (final s in opcionesUnicas(nombres)) s: s,
    };
  }

  bool get _hayFiltros =>
      filtroSucursal.isNotEmpty ||
      filtroEstado.isNotEmpty ||
      filtroDesde != null ||
      filtroHasta != null;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      filtroSucursal = '';
      filtroEstado = '';
      filtroDesde = null;
      filtroHasta = null;
    });
  }

  //LIMPIAR FORMULARIO//////////////////////////////////////////////////////////
  void limpiarFormulario() {
    sucursalController.clear();
    HoraFechaVentaController.clear();
    EstadoVentaController.text = 'Activo';
    estadoSeleccionado = 'Activo';
    CodigoVentaController.clear();
    productosTemp.clear(); // <-- Limpia la lista temporal de productos
  }

  // NUEVO PRODUCTO/////////////////////////////////////////////////////////////
  void nuevoProducto() {
    limpiarFormulario();
    cargarProductos();
    // El código lleva el prefijo de la sucursal: se calcula al elegirla
    CodigoVentaController.text = '';
    cargarSucursales().then((_) => _actualizarCodigoVenta());
    HoraFechaVentaController.text = DateTime.now().toString().substring(0, 16);
    EstadoVentaController.text = 'Activo';
    _ventaIdNueva = VentasRef.doc().id;
    _codigoVentaReservado = null;
    _prefijoVentaReservado = null;
    setState(() {
      ventaSeleccionado = null;
      vista = 'nuevo';
    });
  }

  // EDITAR///////////////////////////////////////////////////////////////////////////
  void editarVenta(CRUDVentas venta) {
    cargarProductos();
    cargarSucursales(elegirPorDefecto: false);
    CodigoVentaController.text = venta.codigoV;
    sucursalController.text = venta.sucursalU;
    estadoSeleccionado = venta.estado;
    HoraFechaVentaController.text = venta.fecha;
    EstadoVentaController.text = venta.estado;

    productosTemp = venta.productos.map((p) {
      return ProductList(
        codigo: p.codigo,
        nombre: p.nombre,
        cantidad: p.cantidad,
        precio: p.precio,
        productoId: p.productoId,
      );
    }).toList();

    setState(() {
      ventaSeleccionado = venta;
      vista = 'editar';
    });
  }

  // Registrar en auditoría
  void _auditarVenta(
    TipoEvento tipo,
    String descripcion,
    CRUDVentas v, {
    String? detalle,
  }) {
    AuditoriaService().registrarSeguro(
      modulo: 'Ventas',
      tipo: tipo,
      descripcion: descripcion,
      idReferencia: v.codigoV,
      productos: v.productos
          .map(
            (p) => ProductoMovimiento(
              nombre: p.nombre,
              cantidad: p.cantidad.round(),
              detalle: '${p.cantidad} x C\$ ${p.precio.toStringAsFixed(2)}',
            ),
          )
          .toList(),
      datosAdicionales: [
        CampoInfo('Venta', v.codigoV),
        CampoInfo('Sucursal', v.sucursalU),
        CampoInfo('Estado', v.estado),
        CampoInfo('Fecha', v.fecha),
        CampoInfo('Total', 'C\$ ${v.total.toStringAsFixed(2)}'),
        if (detalle != null) CampoInfo('Detalle', detalle),
      ],
    );
  }

  // Nombre del usuario que registra la venta
  String _nombreVendedor() {
    final p = Permisos.instance;
    if (p.nombre.isNotEmpty) return p.nombre;
    if (p.correo.isNotEmpty) return p.correo;
    return 'Usuario';
  }

  // Prefijo de la sucursal elegida en la venta (V si no se encuentra)
  Future<String> _prefijoVenta() async {
    final p = await CodigosSucursal.prefijoDe(
      FirebaseFirestore.instance,
      sucursalController.text,
    );
    return p ?? 'V';
  }

  // Muestra el código de la próxima venta de la sucursal elegida (N001, S001...)
  Future<void> _actualizarCodigoVenta() async {
    if (vista != 'nuevo') return;
    try {
      final prefijo = await _prefijoVenta();
      if (!mounted || vista != 'nuevo') return;
      setState(() {
        CodigoVentaController.text = generarCodigoVenta(Listventas, prefijo);
      });
    } catch (e) {
      // Se vuelve a calcular al guardar
      print('No se pudo calcular el código de venta: $e');
    }
  }

  // GUARDAR///////////////////////////////////////////////////////////////////
  Future<void> guardarRegistro() async {
    // Ignora toques mientras hay un guardado en curso
    if (_guardandoVenta) return;
    setState(() => _guardandoVenta = true);
    try {
      await _guardarRegistro();
    } finally {
      if (mounted) setState(() => _guardandoVenta = false);
    }
  }

  Future<void> _guardarRegistro() async {
    if (productosTemp.isEmpty) {
      mostrarMensaje('Agregue al menos un producto');
      return;
    }
    // El vendedor usa su sucursal
    if (!Permisos.instance.puedeElegirSucursalDeVenta) {
      final propia = Permisos.instance.sucursal;
      if (propia.isEmpty) {
        mostrarMensaje(
            'Tu usuario no tiene sucursal asignada. Pídele al administrador que te asigne una.');
        return;
      }
      sucursalController.text = listaSucursales.firstWhere(
        (n) => _norm(n) == _norm(propia),
        orElse: () => propia,
      );
    }
    try {
      if (vista == 'nuevo') {
        // Código con el prefijo de la sucursal, tomado del servidor para no
        // repetir uno que otra persona acaba de usar
        final prefijo = await _prefijoVenta();
        if (_codigoVentaReservado == null || _prefijoVentaReservado != prefijo) {
          _codigoVentaReservado = await CodigosSucursal.reservar(
            db: FirebaseFirestore.instance,
            coleccion: VentasRef.path,
            campo: 'codigoV',
            prefijo: prefijo,
          );
          _prefijoVentaReservado = prefijo;
        }
        final codigoNuevo = _codigoVentaReservado!;
        CodigoVentaController.text = codigoNuevo;
        final nuevo = CRUDVentas(
          codigoV: codigoNuevo,
          estado: estadoSeleccionado,
          sucursalU: sucursalController.text.trim().isEmpty ? 'Norte' : sucursalController.text.trim(),
          productos: List.from(productosTemp),
          fecha: HoraFechaVentaController.text.trim().isEmpty ? DateTime.now().toString().substring(0, 16) : HoraFechaVentaController.text.trim(),
          NombreUsuarioV: _nombreVendedor(),
        );

        final ventaId = _ventaIdNueva ??= VentasRef.doc().id;
        nuevo.id = await registrarVentaConStock(nuevo, ventaId: ventaId);
        _ventaIdNueva = null;
        _codigoVentaReservado = null;
        _prefijoVentaReservado = null;
        _auditarVenta(TipoEvento.crear, 'Venta ${nuevo.codigoV} registrada', nuevo);
        if (!mounted) return;
        setState(() {
          vista = 'lista';
        });
        limpiarFormulario();
        mostrarMensaje('Venta registrada correctamente');
      } else {
        final ventaG = ventaSeleccionado;
        if (ventaG == null || ventaG.id == null) {
          mostrarMensaje('No se encontró el registro para actualizar');
          return;
        }
        // Copia para no dejar la venta a medias
        final anteriores = List<ProductList>.from(ventaG.productos);
        final sucursalAnterior = ventaG.sucursalU;
        final actualizada = CRUDVentas(
          id: ventaG.id,
          codigoV: ventaG.codigoV,
          estado: estadoSeleccionado,
          sucursalU: sucursalController.text.trim().isEmpty ? 'Norte' : sucursalController.text.trim(),
          fecha: HoraFechaVentaController.text.trim(),
          productos: List.from(productosTemp),
          NombreUsuarioV: ventaG.NombreUsuarioV,
        );
        await actualizarVentaConStock(
          actualizada,
          anteriores: anteriores,
          sucursalAnterior: sucursalAnterior,
        );
        ventaG.estado = actualizada.estado;
        ventaG.sucursalU = actualizada.sucursalU;
        ventaG.fecha = actualizada.fecha;
        ventaG.productos = actualizada.productos;
        _auditarVenta(TipoEvento.editar, 'Venta ${ventaG.codigoV} actualizada', ventaG);
        if (!mounted) return;

        setState(() {
          vista = 'informacion';
        });
        mostrarMensaje('Venta actualizada correctamente');
      }
    } on VentaDuplicadaException catch (e) {
      // El primer toque sí se guardó: se sale del formulario sin duplicar
      _ventaIdNueva = null;
      _codigoVentaReservado = null;
      _prefijoVentaReservado = null;
      if (!mounted) return;
      setState(() {
        vista = 'lista';
      });
      limpiarFormulario();
      mostrarMensaje(e.mensaje);
    } catch (e) {
      mostrarMensaje(_textoErrorVenta(e, 'Error al guardar'));
      print(' ERROR AL REGIISTRAR LA VENTA: $e');
    }
  }

  // ELIMINAR/////////////////////////////////////////////////////////////////
  void eliminarRegistro() {
    if (ventaSeleccionado == null) return;
    final venta = ventaSeleccionado!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Apariencia.instance.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Eliminar registro',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          content: Text(
            '¿Está seguro de eliminar el registro "${venta.codigoV}"?',
            style: TextStyle(fontSize: 14, color: _textoClaro),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: _textoClaro),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (venta.id == null) {
                  mostrarMensaje('Este registro no tiene ID de Firestore');
                  return;
                }
                if (_procesandoVenta) return;
                _procesandoVenta = true;

                try {
                  await eliminarVentaConStock(venta);
                  _auditarVenta(TipoEvento.eliminar, 'Venta ${venta.codigoV} eliminada', venta);
                  if (!mounted) return;
                  setState(() {
                    Listventas.remove(venta);
                    ventaSeleccionado = null;
                    vista = 'lista';
                  });

                  if (context.mounted) Navigator.pop(context);
                  mostrarMensaje('Registro eliminado correctamente');
                } catch (e) {
                  if (context.mounted) Navigator.pop(context);
                  mostrarMensaje(_textoErrorVenta(e, 'Error al eliminar'));
                  print('ERROR AL ELIMINAR EL REGISTRO: $e');
                } finally {
                  _procesandoVenta = false;
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  // cargar Productos/////////////////////////////////////////////////////////////////
  List<ProductList> listaProductos = [];

  Future<void> cargarProductos() async {
    try {
      final prods = await cargarProductosDb();
      if (!mounted) return;
      setState(() {
        listaProductos = prods;
        errorProductos = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorProductos = e.toString();
      });
    }
  }

  // Cargar sucursales
  Future<void> cargarSucursales({bool elegirPorDefecto = true}) async {
    setState(() {
      cargandoSucursales = true;
    });
    try {
      final nombres = await cargarSucursalesDb();

      String? elegida;
      if (!Permisos.instance.puedeElegirSucursalDeVenta) {
        // Vendedor: sucursal fija
        final propia = Permisos.instance.sucursal;
        elegida = nombres.firstWhere(
          (n) => _norm(n) == _norm(propia),
          orElse: () => propia,
        );
        if (elegida.isEmpty) elegida = null;
      } else if (elegirPorDefecto) {
        final deUsuario = await cargarSucursalUsuarioDb();
        for (final n in nombres) {
          if (deUsuario.isNotEmpty && _norm(n) == _norm(deUsuario)) {
            elegida = n;
            break;
          }
        }
        elegida ??= nombres.isNotEmpty
            ? nombres.first
            : (deUsuario.isNotEmpty ? deUsuario : null);
      }

      if (!mounted) return;
      setState(() {
        listaSucursales = nombres;
        cargandoSucursales = false;
        if (elegida != null) sucursalController.text = elegida;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargandoSucursales = false;
      });
      mostrarMensaje('No se pudieron cargar las sucursales: $e');
    }
  }

  // ACTIVAR / DESACTIVAR////////////////////////////////////////////////////////
  Future<void> cambiarEstadodelRegistro() async {
    if (ventaSeleccionado == null) return;
    final venta = ventaSeleccionado!;
    final anular = venta.estado == 'Activo';
    if (venta.id == null) {
      mostrarMensaje('Este Registro no tiene ID de Firestore');
      return;
    }

    if (anular) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Apariencia.instance.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Anular venta',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          content: Text(
            '¿Anular la venta "${venta.codigoV}"? Los productos regresarán '
            'al stock y la venta dejará de contar en los reportes. '
            'Quedará guardada en el historial.',
            style: TextStyle(fontSize: 14, color: _textoClaro),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: _textoClaro),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojo,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Anular'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    if (_procesandoVenta) return;
    _procesandoVenta = true;
    try {
      if (anular) {
        await anularVentaConStock(venta);
      } else {
        await reactivarVentaConStock(venta);
      }
      final estadoAnterior = venta.estado;
      final nuevoEstado = anular ? 'Inactivo' : 'Activo';
      venta.estado = nuevoEstado;
      _auditarVenta(
        TipoEvento.editar,
        anular
            ? 'Venta ${venta.codigoV} anulada (stock devuelto)'
            : 'Venta ${venta.codigoV} reactivada',
        venta,
        detalle: 'Estado: $estadoAnterior → $nuevoEstado',
      );
      if (!mounted) return;
      setState(() {
        venta.estado = nuevoEstado;
      });
      mostrarMensaje(
        anular
            ? 'Venta anulada. Los productos regresaron al stock.'
            : 'Venta reactivada.',
      );
    } catch (e) {
      var texto = _textoErrorVenta(e, 'Error al cambiar el estado');
      if (!anular && texto.startsWith('Stock insuficiente')) {
        texto += ' Registra una entrada de stock en Inventario y vuelve a intentarlo.';
      }
      mostrarMensaje(texto);
      print(' ERROR AL CAMBIAR ESTADO: $e');
    } finally {
      _procesandoVenta = false;
    }
  }

  // Mensaje legible de un error. En web, las excepciones lanzadas dentro de
  // una transacción llegan envueltas ("Dart exception: ..."), por eso se
  // extrae el texto en vez de depender del tipo.
  String _textoErrorVenta(Object e, String prefijoGenerico) {
    if (e is VentaStockException) return e.mensaje;
    final t = e.toString();
    const marca = 'Dart exception: ';
    final i = t.indexOf(marca);
    if (i != -1) return t.substring(i + marca.length).trim();
    return '$prefijoGenerico: $e';
  }

  //funcion de mensaje flotante
  // MENSAJE////////////////////////////////////////////////////////////////////
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  //-----agrega la lista de productos -----------------------------------------
  Future<void> agregarProductoVenta() async {
    await cargarProductos();
    if (!mounted) return;

    final cantidadController = TextEditingController(text: '1');
    ProductList? productoSeleccionadoDialogo;
    String? errorCantidad; // mensaje dentro del diálogo
    // Sube cada vez que se agrega un producto para limpiar el desplegable
    var reinicioSelector = 0;

    // Unidades que se pueden vender de un producto: su stock actual, más lo
    // que esta misma venta ya tenía reservado (si se está editando), menos lo
    // que ya se agregó en esta pantalla.
    double disponibleDe(ProductList p) {
      var disponible = p.stock;
      if (ventaSeleccionado != null) {
        for (final original in ventaSeleccionado!.productos) {
          if (original.productoId == p.productoId) {
            disponible += original.cantidad;
          }
        }
      }
      for (final agregado in productosTemp) {
        if (agregado.productoId == p.productoId) {
          disponible -= agregado.cantidad;
        }
      }
      return disponible < 0 ? 0 : disponible;
    }

    String numeroLimpio(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final sucursalVenta = sucursalController.text.trim();

            // Solo productos asignados a la sucursal de la venta.
            // Si la sucursal no tiene productos, no se muestra ninguno.
            final disponibles = listaProductos.where((p) {
              if (sucursalVenta.isEmpty) return true;
              return _norm(p.sucursal) == _norm(sucursalVenta);
            }).toList();

            String? aviso;
            if (sucursalVenta.isNotEmpty && disponibles.isNotEmpty) {
              aviso = 'Productos activos de ${etiquetaSucursal(sucursalVenta)}';
            }

            return AlertDialog(
              backgroundColor: Apariencia.instance.superficie,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Agregar productos a la venta',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (aviso != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        aviso,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textoClaro,
                        ),
                      ),
                    ),
                  _etiqueta('Producto (${disponibles.length})'),
                  if (errorProductos != null)
                    Text(
                      'No se pudieron cargar los productos:\n$errorProductos',
                      style: const TextStyle(fontSize: 12, color: _rojo),
                    )
                  else if (disponibles.isEmpty)
                    Text(
                      sucursalVenta.isEmpty
                          ? 'No hay productos activos registrados. '
                              'Regístralos en el módulo Productos.'
                          : 'No hay productos asignados a '
                              '${etiquetaSucursal(sucursalVenta)}.',
                      style: const TextStyle(fontSize: 13, color: _rojo),
                    )
                  else
                    // Desplegable de productos (agotados quedan deshabilitados)
                    DropdownButtonFormField<String>(
                      // La llave reinicia el campo después de agregar
                      key: ValueKey('prod-$reinicioSelector'),
                      initialValue: productoSeleccionadoDialogo?.productoId,
                      isExpanded: true,
                      hint: const Text('Seleccionar'),
                      decoration: _decoracionCampo(),
                      items: disponibles.map((producto) {
                        final libre = disponibleDe(producto);
                        return DropdownMenuItem<String>(
                          value: producto.productoId,
                          enabled: libre > 0,
                          child: Text(
                            '${producto.nombre} · ${_dinero(producto.precio)} · '
                            '${libre <= 0 ? 'Agotado' : 'Stock: ${numeroLimpio(libre)}'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setStateDialog(() {
                          productoSeleccionadoDialogo = disponibles
                              .firstWhere((p) => p.productoId == id);
                          errorCantidad = null;
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  _etiqueta('Cantidad'),
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoracionCampo(hint: '1'),
                    onChanged: (_) {
                      if (errorCantidad != null) {
                        setStateDialog(() => errorCantidad = null);
                      }
                    },
                  ),
                  if (productoSeleccionadoDialogo != null &&
                      errorCantidad == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Disponible: ${numeroLimpio(disponibleDe(productoSeleccionadoDialogo!))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textoClaro,
                        ),
                      ),
                    ),
                  if (errorCantidad != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        errorCantidad!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _rojo,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: _textoClaro),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (productoSeleccionadoDialogo == null) {
                      mostrarMensaje('Selecciona un producto');
                      return;
                    }
                    final cantidad = double.tryParse(
                      cantidadController.text.trim().replaceAll(',', '.'),
                    );
                    if (cantidad == null || cantidad <= 0) {
                      setStateDialog(() {
                        errorCantidad = 'La cantidad debe ser un número mayor a 0';
                      });
                      return;
                    }

                    final elegido = productoSeleccionadoDialogo!;
                    final disponible = disponibleDe(elegido);
                    if (cantidad > disponible) {
                      setStateDialog(() {
                        errorCantidad = disponible <= 0
                            ? 'Stock insuficiente: "${elegido.nombre}" está agotado.'
                            : 'Stock insuficiente de "${elegido.nombre}": '
                                'disponible ${numeroLimpio(disponible)}, '
                                'se necesitan ${numeroLimpio(cantidad)}.';
                      });
                      return;
                    }

                    setState(() {
                      productosTemp.add(
                        ProductList(
                          codigo: productoSeleccionadoDialogo!.codigo,
                          nombre: productoSeleccionadoDialogo!.nombre,
                          cantidad: cantidad,
                          precio: productoSeleccionadoDialogo!.precio,
                          productoId: productoSeleccionadoDialogo!.productoId,
                          sucursal: productoSeleccionadoDialogo!.sucursal,
                        ),
                      );
                    });

                    setStateDialog(() {
                      productoSeleccionadoDialogo = null;
                      cantidadController.text = '1';
                      reinicioSelector++;
                    });

                    mostrarMensaje('Producto agregado a la lista');
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    // No se libera de inmediato: el diálogo todavía se está animando al
    // cerrarse y usar un controller ya liberado provoca la pantalla roja.
    Future.delayed(const Duration(milliseconds: 600), cantidadController.dispose);
  }

  List<SucursalList> listaSucursal = [];
  List<UsuarioData> SucursalAsignada = [];

  Future<void> _seleccionarFechaHora(
      BuildContext context,
      TextEditingController controller,
  ) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: _temaPicker,
    );

    if (fechaSeleccionada == null) return;

    if (!mounted) return;
    final TimeOfDay? horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: _temaPicker,
    );

    if (horaSeleccionada == null) return;

    final DateTime fechaHoraFinal = DateTime(
      fechaSeleccionada.year,
      fechaSeleccionada.month,
      fechaSeleccionada.day,
      horaSeleccionada.hour,
      horaSeleccionada.minute,
    );

    setState(() {
      controller.text = fechaHoraFinal.toString().substring(0, 16);
    });
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.ventas),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior solo en la lista
            if (vista == 'lista')
              ChinoTopBar(scaffoldKey: _scaffoldKey, subtitulo: 'Ventas'),
            Expanded(
              child: vista == 'lista'
                  ? construirLista()
                  : vista == 'nuevo'
                  ? construirFormulario(false)
                  : vista == 'editar'
                  ? construirFormulario(true)
                  : construirInformacion(),
            ),
          ],
        ),
      ),
    );
  }

  // Botón volver
  Widget _botonVolver(VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
      label: Text('Ventas', style: TextStyle(color: _textoOscuro)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
    );
  }

  //Targetas para mostrar los datos de la venta///////////////////////////////////
  Widget construirLista() {
    final lista = ventasFiltrados;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Registro de ventas por sucursal',
            style: TextStyle(fontSize: 13, color: _textoClaro),
          ),
          const SizedBox(height: 16),

          // Buscador
          TextField(
            onChanged: (value) {
              setState(() {
                textoBusqueda = value;
              });
            },
            decoration: _decoracionCampo(hint: 'Buscar una venta...').copyWith(
              prefixIcon: Icon(Icons.search, color: _textoClaro),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Filtros desplegables
          BarraFiltros(
            hayFiltros: _hayFiltros,
            onLimpiar: _quitarFiltros,
            filtros: [
              FiltroDesplegable(
                icono: Icons.storefront_outlined,
                titulo: 'Sucursal',
                valor: filtroSucursal,
                opciones: _opcionesSucursal,
                onChanged: (v) => setState(() => filtroSucursal = v),
              ),
              FiltroDesplegable(
                icono: Icons.toggle_on_outlined,
                titulo: 'Estado',
                valor: filtroEstado,
                opciones: const {
                  '': 'Todos los estados',
                  'Activo': 'Activo',
                  'Inactivo': 'Inactivo',
                },
                onChanged: (v) => setState(() => filtroEstado = v),
              ),
              FiltroFecha(
                etiqueta: 'Desde',
                fecha: filtroDesde,
                maximo: filtroHasta,
                onChanged: (f) => setState(() => filtroDesde = f),
              ),
              FiltroFecha(
                etiqueta: 'Hasta',
                fecha: filtroHasta,
                minimo: filtroDesde,
                onChanged: (f) => setState(() => filtroHasta = f),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botón Nuevo
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: nuevoProducto,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorAcento,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Listado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 10),

          if (cargandoVenta)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _colorAcento),
              ),
            )
          else if (lista.isEmpty)
            _MensajeEstado(
              icono: Icons.point_of_sale_outlined,
              texto: _hayFiltros || textoBusqueda.isNotEmpty
                  ? 'No hay ventas con los filtros seleccionados.'
                  : 'No se encontraron ventas.\n'
                      'Toca "Nuevo" para registrar la primera.',
            )
          else
            Column(children: lista.map(tarjetaventas).toList()),
        ],
      ),
    );
  }

  //Targetas para mostrar los datos de la venta///////////////////////////////////

  //Targetas de venta ///////////////////////////////////////////////////////////
  Widget tarjetaventas(CRUDVentas ventaT) {
    final activo = ventaT.estado == 'Activo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            ventaSeleccionado = ventaT;
            vista = 'informacion';
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ventaT.codigoV,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Sucursal: ${ventaT.sucursalU} · Productos: ${ventaT.productos.length}',
                style: TextStyle(fontSize: 12, color: _textoClaro),
              ),
              Divider(height: 20, color: _colorBorde),
              Row(
                children: [
                  _EtiquetaEstado(activo: activo),
                  const SizedBox(width: 10),
                  Text(
                    'Total: ${_dinero(_totalVenta(ventaT))}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _verde,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      ventaT.fecha,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textoOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: _textoClaro),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  //Registro de ventas Campos //////////////////////////////////////////////////
  //Formulario detallado de as ventas //////////////////////////////////////////
  Widget construirInformacion() {
    final ventaI = ventaSeleccionado!;
    final activo = ventaI.estado == 'Activo';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botonVolver(() {
            setState(() {
              vista = 'lista';
            });
          }),
          const SizedBox(height: 8),

          // Card 1: Registro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _decoracionTarjeta,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venta',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ventaI.codigoV,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _EtiquetaEstado(activo: activo),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _dinero(_totalVenta(ventaI)),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _verde,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Card 2: Información
          _tituloSeccion('Información'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: _decoracionTarjeta,
            child: Column(
              children: [
                _FilaInfo('Código de venta', ventaI.codigoV),
                _FilaInfo('Sucursal', ventaI.sucursalU),
                _FilaInfo(
                  'Nombre de Usuario',
                  ventaI.NombreUsuarioV.isEmpty ? '—' : ventaI.NombreUsuarioV,
                ),
                _FilaInfo('Fecha', ventaI.fecha),
                _FilaInfo('Estado', ventaI.estado, ultima: true),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Card Productos (se adapta a la cantidad de registros)
          _tituloSeccion('Productos'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: _decoracionTarjeta,
            child: ventaI.productos.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Esta venta no tiene productos registrados.',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                  )
                : Column(
                    children: [
                      for (final producto in ventaI.productos)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _colorBorde),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      producto.nombre,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _textoOscuro,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cantidad: ${_numero(producto.cantidad)} · ${_dinero(producto.precio)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textoClaro,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _dinero(producto.precio * producto.cantidad),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _verde,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _FilaInfo(
                        'Total',
                        _dinero(_totalVenta(ventaI)),
                        ultima: true,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),

          if (Permisos.instance.puedeGestionarVenta(ventaI.sucursalU)) ...[
          _tituloSeccion('Acciones'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: activo ? () => editarVenta(ventaI) : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorAcento,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: 'Eliminar',
            icono: Icons.delete_outline,
            color: _rojo,
            onPressed: eliminarRegistro,
          ),
          const SizedBox(height: 10),
          _BotonContorno(
            texto: activo ? 'Anular venta' : 'Reactivar venta',
            icono: activo ? Icons.block : Icons.restore,
            color: _colorAcento,
            onPressed: cambiarEstadodelRegistro,
          ),
          ],
        ],
      ),
    );
  }

// Registro de ventas Campos //////////////////!!!!!/////////////////////////////
  Widget construirFormulario(bool editar) {
    // Asegura que el estado esté en la lista
    final estados = {..._kEstados, estadoSeleccionado}.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botonVolver(() {
            setState(() {
              vista = 'lista';
            });
          }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              editar ? 'Editar venta' : 'Nueva venta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textoOscuro,
              ),
            ),
          ),
          const SizedBox(height: 22),

// Campos autocompletables ////////////////////////////////////////////////
          campoSoloLectura('Código', CodigoVentaController),
          const SizedBox(height: 16),
          campoSucursal(),
          const SizedBox(height: 16),
          campoFechaHora('Hora y fecha', HoraFechaVentaController),
          const SizedBox(height: 16),

          _etiqueta('Estado'),
          DropdownButtonFormField<String>(
            value: estadoSeleccionado,
            isExpanded: true,
            items: estados
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            // El estado se cambia con "Anular venta" / "Reactivar venta"
            // en el detalle, porque mueve el stock.
            onChanged: null,
            decoration: _decoracionCampo(),
          ),
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Para anular o reactivar una venta usa el botón de su detalle.',
              style: TextStyle(fontSize: 12, color: _textoClaro),
            ),
          ),
          const SizedBox(height: 22),

          _tituloSeccion('Productos de la venta'),
          const SizedBox(height: 10),
          if (productosTemp.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'No hay productos agregados',
                style: TextStyle(fontSize: 13, color: _textoClaro),
              ),
            )
          else
            Column(
              children: productosTemp.map((prod) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  decoration: _decoracionTarjeta,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prod.nombre,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textoOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cantidad: ${_numero(prod.cantidad)} · Precio: ${_dinero(prod.precio)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _textoClaro,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _dinero(prod.precio * prod.cantidad),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _verde,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            productosTemp.remove(prod);
                          });
                        },
                        icon: const Icon(Icons.delete_outline, color: _rojo),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: agregarProductoVenta,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                productosTemp.isEmpty
                    ? 'Añadir producto'
                    : 'Añadir otro producto',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _colorAcento,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _colorAcento.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card de Total de la venta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: _decoracionTarjeta,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total de la venta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${productosTemp.length} producto(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textoClaro,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _dinero(_totalProductosTemp),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _verde,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardandoVenta ? null : guardarRegistro,
              icon: _guardandoVenta
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(editar ? 'GUARDAR CAMBIOS' : 'GUARDAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorAcento,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  vista = editar ? 'informacion' : 'lista';
                });
                limpiarFormulario();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _textoOscuro,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _colorBorde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget campoFechaHora(String titulo, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(titulo),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _seleccionarFechaHora(context, controller),
          decoration: _decoracionCampo().copyWith(
            suffixIcon: Icon(
              Icons.calendar_today,
              size: 18,
              color: _textoClaro,
            ),
          ),
        ),
      ],
    );
  }

  // Selector de sucursal
  Widget campoSucursal() {
    // Vendedor: sucursal fija
    if (!Permisos.instance.puedeElegirSucursalDeVenta) {
      final propia = Permisos.instance.sucursal;
      if (propia.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _etiqueta('Sucursal'),
            const Text(
              'Tu usuario no tiene sucursal asignada. '
              'Pídele al administrador que te asigne una.',
              style: TextStyle(fontSize: 12, color: _rojo),
            ),
          ],
        );
      }
      final visible = TextEditingController(text: etiquetaSucursal(propia));
      return campoSoloLectura('Sucursal', visible);
    }

    final actual = sucursalController.text.trim();
    final nombres = [...listaSucursales];
    // Conserva la sucursal si ya no está activa
    if (actual.isNotEmpty && !nombres.any((n) => _norm(n) == _norm(actual))) {
      nombres.add(actual);
    }
    String? valor;
    for (final n in nombres) {
      if (_norm(n) == _norm(actual)) valor = n;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('Sucursal'),
        if (cargandoSucursales && nombres.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LinearProgressIndicator(color: _colorAcento),
          )
        else if (nombres.isEmpty)
          const Text(
            'No hay sucursales activas. Crea una en el módulo Sucursales.',
            style: TextStyle(fontSize: 12, color: _rojo),
          )
        else
          DropdownButtonFormField<String>(
            value: valor,
            isExpanded: true,
            hint: const Text('Seleccionar sucursal'),
            items: nombres
                .map(
                  (n) => DropdownMenuItem(
                    value: n,
                    child: Text(etiquetaSucursal(n)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  sucursalController.text = v;
                });
                _actualizarCodigoVenta();
              }
            },
            decoration: _decoracionCampo(),
          ),
      ],
    );
  }

  Widget campoSoloLectura(String titulo, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(titulo),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: _decoracionCampo(soloLectura: true),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _subVentas?.cancel();
    _subProductos?.cancel();
    CodigoVentaController.dispose();
    HoraFechaVentaController.dispose();
    EstadoVentaController.dispose();
    sucursalController.dispose();

    super.dispose();
  }
}

class _MensajeEstado extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _MensajeEstado({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 32, color: _textoClaro),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textoClaro),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  final bool activo;

  const _EtiquetaEstado({required this.activo});

  @override
  Widget build(BuildContext context) {
    final color = activo ? const Color(0xFF2E9E4F) : const Color(0xFF8A8A8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool ultima;

  const _FilaInfo(this.etiqueta, this.valor, {this.ultima = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: _colorBorde)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13, color: _textoClaro),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _textoOscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonContorno extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback? onPressed;

  const _BotonContorno({
    required this.texto,
    required this.icono,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}