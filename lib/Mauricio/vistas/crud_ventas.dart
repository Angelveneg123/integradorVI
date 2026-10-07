import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../firebase_options.dart';
import '../modelos/FuncionVenta.dart';
import '../controladores/ConeccionFirebase.dart';
import '../../Chino/vistas/AppDrawer.dart';
import '../../Henry/modelos/sucursal_modelo.dart' show etiquetaSucursal;

// Mismos colores y estilos que usan Productos, Materia Prima, Stock,
// Reportes y Sucursales, para que todos los CRUDs se vean igual.
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);
const Color _fondoSoloLectura = Color(0xFFF3EEE8);
const Color _verde = Color(0xFF1F7A3D);
const Color _rojo = Color(0xFFB3261E);

const List<String> _kEstados = ['Activo', 'Inactivo'];

InputDecoration _decoracionCampo({String? hint, bool soloLectura = false}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: soloLectura ? _fondoSoloLectura : _fondoInput,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _colorBorde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _colorAcento),
    ),
  );
}

BoxDecoration get _decoracionTarjeta => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _colorBorde),
);

String _dinero(double valor) => 'C\$ ${valor.toStringAsFixed(2)}';

String _numero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

double _totalVenta(CRUDVentas v) => v.total;

/// Nombre de sucursal sin el prefijo "Sucursal" y en minúsculas, para comparar
/// "Centro" con "Sucursal Centro".
String _norm(String s) =>
    s.trim().toLowerCase().replaceFirst(RegExp(r'^sucursal\s+'), '');

Widget _etiqueta(String texto) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(texto, style: const TextStyle(fontSize: 12, color: _textoClaro)),
);

Widget _tituloSeccion(String texto) => Text(
  texto,
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: _textoOscuro,
  ),
);

/// Calendario/reloj con el color de acento de la app.
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
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  // Llave para abrir la barra lateral desde la barra superior.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // FIRESTORE
  List<CRUDVentas> Listventas = [];
  bool cargandoVenta = true;

  @override
  void initState() {
    super.initState();
    cargarVenta();
  }

  //Elementos de carga de datos----------------------------
  Future<void> cargarVenta() async {
    final lista = await cargarVentaDb();
    if (!mounted) return;
    setState(() {
      Listventas = lista;
      cargandoVenta = false;
    });
  }

  CRUDVentas? ventaSeleccionado;
  String filtro = 'Todos';
  String textoBusqueda = '';

  // CONTROLADORES
  final CodigoVentaController = TextEditingController();
  final sucursalController = TextEditingController();
  final HoraFechaVentaController = TextEditingController();
  final EstadoVentaController = TextEditingController();

  String estadoSeleccionado = 'Activo';
  String vista = 'lista';
  List<ProductList> productosTemp = [];

  // Sucursales activas leídas de Firestore (colección `sucursales`).
  List<String> listaSucursales = [];
  bool cargandoSucursales = false;

  // Error (si lo hubo) al leer los productos de Firestore.
  String? errorProductos;

  double get _totalProductosTemp =>
      productosTemp.fold<double>(0, (suma, p) => suma + p.precio * p.cantidad);

  //FILTRAR Ventas////////////////////////////////////////////////////////////////
  List<CRUDVentas> get ventasFiltrados {
    final listaFiltrada = Listventas.where((ventas) {
      final coincideBusqueda = ventas.codigoV.toLowerCase().contains(
        textoBusqueda.toLowerCase(),
      );

      bool coincideFiltro = true;

      if (filtro == 'Activos') {
        coincideFiltro = ventas.estado == 'Activo';
      }
      if (filtro == 'Inactivos') {
        coincideFiltro = ventas.estado == 'Inactivo';
      }
      if (filtro == 'Mas resiente ' ||
          filtro == 'Más reciente' ||
          filtro == 'Mas reciente') {
        coincideFiltro = true;
      }
      return coincideBusqueda && coincideFiltro;
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
    cargarSucursales();
    CodigoVentaController.text = generarCodigo(Listventas);
    HoraFechaVentaController.text = DateTime.now().toString().substring(0, 16);
    EstadoVentaController.text = 'Activo';
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
      );
    }).toList();

    setState(() {
      ventaSeleccionado = venta;
      vista = 'editar';
    });
  }

  // GUARDAR///////////////////////////////////////////////////////////////////
  Future<void> guardarRegistro() async {
    if (productosTemp.isEmpty) {
      mostrarMensaje('Agregue al menos un producto');
      return;
    }
    try {
      if (vista == 'nuevo') {
        final nuevo = CRUDVentas(
          codigoV: CodigoVentaController.text.trim().isEmpty ? generarCodigo(Listventas) : CodigoVentaController.text.trim(),
          estado: estadoSeleccionado,
          sucursalU: sucursalController.text.trim().isEmpty ? 'Norte' : sucursalController.text.trim(),
          productos: List.from(productosTemp),
          fecha: HoraFechaVentaController.text.trim().isEmpty ? DateTime.now().toString().substring(0, 16) : HoraFechaVentaController.text.trim(),
        );

        final docRef = await VentasRef.add(ventaToMap(nuevo));
        nuevo.id = docRef.id;
        if (!mounted) return;
        setState(() {
          Listventas.add(nuevo);
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
        ventaG.estado = estadoSeleccionado;
        ventaG.sucursalU = sucursalController.text.trim().isEmpty ? 'Norte' : sucursalController.text.trim();
        ventaG.fecha = HoraFechaVentaController.text.trim();
        ventaG.productos = List.from(productosTemp);
        await VentasRef.doc(ventaG.id).update(ventaToMap(ventaG));
        if (!mounted) return;

        setState(() {
          vista = 'informacion';
        });
        mostrarMensaje('Venta actualizada correctamente');
      }
    } catch (e) {
      mostrarMensaje('Error al guardar: $e');
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Eliminar registro',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          content: Text(
            '¿Está seguro de eliminar el registro "${venta.codigoV}"?',
            style: const TextStyle(fontSize: 14, color: _textoClaro),
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

                try {
                  await VentasRef.doc(venta.id).delete();
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
                  mostrarMensaje('Error al eliminar: $e');
                  print('ERROR AL ELIMINAR EL REGISTRO: $e');
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

  // Cargar sucursales ///////////////////////////////////////////////////////////
  // Lee las sucursales activas de Firestore. Si `elegirPorDefecto` es true,
  // deja seleccionada la sucursal del usuario que inició sesión (o la primera).
  Future<void> cargarSucursales({bool elegirPorDefecto = true}) async {
    setState(() {
      cargandoSucursales = true;
    });
    try {
      final nombres = await cargarSucursalesDb();

      String? elegida;
      if (elegirPorDefecto) {
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
    final ventaEstado = ventaSeleccionado!;
    final nuevoEstado = ventaEstado.estado == 'Activo' ? 'Inactivo' : 'Activo';
    if (ventaEstado.id == null) {
      mostrarMensaje('Este Registro no tiene ID de Firestore');
      return;
    }
    try {
      await VentasRef.doc(ventaEstado.id).update({'estado': nuevoEstado});
      if (!mounted) return;
      setState(() {
        ventaEstado.estado = nuevoEstado;
      });
      mostrarMensaje(
        nuevoEstado == 'Activo' ? 'Venta activa' : 'Venta desactivada',
      );
    } catch (e) {
      mostrarMensaje('Error al cambiar el estado: $e');
      print(' ERROR AL CAMBIAR ESTADO: $e');
    }
  }

  // MENSAJE////////////////////////////////////////////////////////////////////
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  //-----agrega la lista de productos -----------------------------------------
  Future<void> agregarProductoVenta() async {
    // Se vuelve a leer Firestore al abrir el diálogo para tener la lista al día.
    await cargarProductos();
    if (!mounted) return;

    final cantidadController = TextEditingController(text: '1');
    ProductList? productoSeleccionadoDialogo;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final sucursalVenta = sucursalController.text.trim();

            // Productos de la sucursal de la venta. Si ninguno coincide (por
            // ejemplo, porque aún no se les asignó sucursal), se muestran todos
            // los activos para no dejar la lista vacía.
            final delaSucursal = listaProductos.where((p) {
              return p.sucursal.trim().isEmpty ||
                  sucursalVenta.isEmpty ||
                  _norm(p.sucursal) == _norm(sucursalVenta);
            }).toList();
            final mostrandoTodos =
                delaSucursal.isEmpty && listaProductos.isNotEmpty;
            final disponibles = mostrandoTodos ? listaProductos : delaSucursal;

            String? aviso;
            if (mostrandoTodos) {
              aviso =
                  'Ningún producto está asignado a ${etiquetaSucursal(sucursalVenta)}; '
                  'se muestran todos los productos activos.';
            } else if (sucursalVenta.isNotEmpty && disponibles.isNotEmpty) {
              aviso = 'Productos activos de ${etiquetaSucursal(sucursalVenta)}';
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
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
                        style: const TextStyle(
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
                    const Text(
                      'No hay productos activos registrados. '
                      'Regístralos en el módulo Productos.',
                      style: TextStyle(fontSize: 13, color: _rojo),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: disponibles.map((producto) {
                            final seleccionado = identical(
                              producto,
                              productoSeleccionadoDialogo,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setStateDialog(() {
                                    productoSeleccionadoDialogo = producto;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: seleccionado
                                        ? _colorAcento.withValues(alpha: 0.10)
                                        : _fondoInput,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: seleccionado
                                          ? _colorAcento
                                          : _colorBorde,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          producto.nombre,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _textoOscuro,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _dinero(producto.precio),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _verde,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _etiqueta('Cantidad'),
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: _decoracionCampo(hint: '1'),
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
                    final cantidad =
                        double.tryParse(cantidadController.text) ?? 1.0;
                    if (cantidad <= 0) {
                      mostrarMensaje('La cantidad debe ser mayor a 0');
                      return;
                    }

                    setState(() {
                      productosTemp.add(
                        ProductList(
                          codigo: productoSeleccionadoDialogo!.codigo,
                          nombre: productoSeleccionadoDialogo!.nombre,
                          cantidad: cantidad,
                          precio: productoSeleccionadoDialogo!.precio,
                          sucursal: productoSeleccionadoDialogo!.sucursal,
                        ),
                      );
                    });

                    setStateDialog(() {
                      productoSeleccionadoDialogo = null;
                      cantidadController.text = '1';
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

    cantidadController.dispose();
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

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.ventas),
      body: SafeArea(
        child: Column(
          children: [
            // La barra superior (con el botón de menú) solo se muestra en la
            // lista; los formularios mantienen su propio encabezado.
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

  // Botón "← Ventas" de las pantallas de formulario y detalle.
  Widget _botonVolver(VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
      label: const Text('Ventas', style: TextStyle(color: _textoOscuro)),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
    );
  }

  // LISTA
  Widget construirLista() {
    final lista = ventasFiltrados;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventas',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
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
              prefixIcon: const Icon(Icons.search, color: _textoClaro),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Filtros tipo pill
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Todos', 'Activos', 'Inactivos']
                .map(filtroBoton)
                .toList(),
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
          const Text(
            'Listado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 10),

          if (cargandoVenta)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _colorAcento),
              ),
            )
          else if (lista.isEmpty)
            const _MensajeEstado(
              icono: Icons.point_of_sale_outlined,
              texto:
                  'No se encontraron ventas.\n'
                  'Toca "Nuevo" para registrar la primera.',
            )
          else
            Column(children: lista.map(tarjetaventas).toList()),
        ],
      ),
    );
  }

  Widget filtroBoton(String nombre) {
    final seleccionado = filtro == nombre;

    return ChoiceChip(
      label: Text(nombre),
      selected: seleccionado,
      onSelected: (_) {
        setState(() {
          filtro = nombre;
        });
      },
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : _textoOscuro,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      selectedColor: _colorAcento,
      backgroundColor: _fondoInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: seleccionado ? _colorAcento : _colorBorde),
      ),
      showCheckmark: false,
    );
  }

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ventaT.codigoV,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Sucursal: ${ventaT.sucursalU} · Productos: ${ventaT.productos.length}',
                style: const TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const Divider(height: 20, color: _colorBorde),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textoOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: _textoClaro),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DETALLE
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

          // Tarjeta resumen
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
                      const Text(
                        'Venta',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ventaI.codigoV,
                        style: const TextStyle(
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
                _FilaInfo('Fecha', ventaI.fecha),
                _FilaInfo('Estado', ventaI.estado, ultima: true),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _tituloSeccion('Productos'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: _decoracionTarjeta,
            child: ventaI.productos.isEmpty
                ? const Padding(
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
                          decoration: const BoxDecoration(
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
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _textoOscuro,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cantidad: ${_numero(producto.cantidad)} · ${_dinero(producto.precio)}',
                                      style: const TextStyle(
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

          _tituloSeccion('Acciones'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => editarVenta(ventaI),
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
            texto: activo ? 'Desactivar' : 'Activar',
            icono: activo
                ? Icons.pause_circle_outline
                : Icons.check_circle_outline,
            color: _colorAcento,
            onPressed: cambiarEstadodelRegistro,
          ),
        ],
      ),
    );
  }

  // FORMULARIO (nuevo / editar)
  Widget construirFormulario(bool editar) {
    // El estado que se guarda es `estadoSeleccionado`; se asegura que el valor
    // actual exista en la lista del desplegable.
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textoOscuro,
              ),
            ),
          ),
          const SizedBox(height: 22),

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
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  estadoSeleccionado = v;
                  EstadoVentaController.text = v;
                });
              }
            },
            decoration: _decoracionCampo(),
          ),
          const SizedBox(height: 22),

          _tituloSeccion('Productos de la venta'),
          const SizedBox(height: 10),
          if (productosTemp.isEmpty)
            const Padding(
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textoOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cantidad: ${_numero(prod.cantidad)} · Precio: ${_dinero(prod.precio)}',
                              style: const TextStyle(
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

          // Total de la venta
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
                      const Text(
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
                        style: const TextStyle(
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
              onPressed: guardarRegistro,
              icon: const Icon(Icons.save_outlined, size: 18),
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
                side: const BorderSide(color: _colorBorde),
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
            suffixIcon: const Icon(
              Icons.calendar_today,
              size: 18,
              color: _textoClaro,
            ),
          ),
        ),
      ],
    );
  }

  // Desplegable con las sucursales activas que están en Firestore.
  Widget campoSucursal() {
    final actual = sucursalController.text.trim();
    final nombres = [...listaSucursales];
    // Si se edita una venta cuya sucursal ya no está activa, se conserva.
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
          const Padding(
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
              style: const TextStyle(color: _textoClaro),
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
            : const Border(bottom: BorderSide(color: _colorBorde)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13, color: _textoClaro),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
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