import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../Chino/modelos/materia_prima_modelo.dart';
import '../../Chino/controladores/materia_prima_service.dart';
import '../../Chino/vistas/AppDrawer.dart';
import '../../Henry/modelos/sucursal_modelo.dart';
import '../../Henry/controladores/sucursales_service.dart';
import '../modelos/productos_modelos.dart';
import '../controladores/productos_service.dart';
import '../../Chino/controladores/auditoria_service.dart';
import '../../Chino/modelos/evento_auditoria_modelo.dart'
    show TipoEvento, CampoInfo;
import '../../Chino/controladores/permisos_service.dart';
import '../../Chino/controladores/apariencia_service.dart';
import '../../Chino/vistas/filtros_comunes.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;
const Color _verde = Color(0xFF1F7A3D);
const Color _rojo = Color(0xFFB3261E);

const List<String> _kEstados = ['Activo', 'Inactivo'];

// Compara sucursales sin mayúsculas ni la palabra "Sucursal"
bool _igualSucursal(String a, String b) {
  String n(String s) =>
      s.trim().toLowerCase().replaceFirst(RegExp(r'^sucursal\s+'), '');
  return n(a) == n(b);
}

// Error a texto corto. En web el error de una transacción llega envuelto
// en "Dart exception: ", por eso se saca el texto de ahí.
String _mensajeError(Object e) {
  var t = e.toString();
  const marca = 'Dart exception: ';
  final i = t.indexOf(marca);
  if (i != -1) t = t.substring(i + marca.length);
  return t.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '').trim();
}

InputDecoration _decoracionCampo({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Apariencia.instance.hint, fontSize: 14),
    filled: true,
    fillColor: _fondoInput,
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

String _dinero(double valor) => 'C\$ ${valor.toStringAsFixed(2)}';

// Lista de productos

// Registrar en auditoría
void _auditarProducto(
  TipoEvento tipo,
  String descripcion,
  Producto p, {
  String? detalle,
}) {
  AuditoriaService().registrarSeguro(
    modulo: 'Productos',
    tipo: tipo,
    descripcion: descripcion,
    idReferencia: p.codigo,
    datosAdicionales: [
      CampoInfo('Producto', p.nombre),
      CampoInfo('Categoría', p.categoria),
      CampoInfo('Sucursal', p.sucursal),
      CampoInfo('Precio', 'C\$ ${p.precio.toStringAsFixed(2)}'),
      CampoInfo('Estado', p.estado),
      if (detalle != null) CampoInfo('Detalle', detalle),
    ],
  );
}

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // Categorías del filtro (incluye las antiguas que existan en los
  // productos y no estén en la lista predeterminada)
  Map<String, String> get _opcionesCategoria {
    final extras = _productos
        .map((p) => p.categoria.trim())
        .where((c) => c.isNotEmpty && !kCategoriasProducto.contains(c))
        .toSet()
        .toList()
      ..sort();
    return {
      '': 'Todas las categorías',
      for (final c in [...kCategoriasProducto, ...extras]) c: c,
    };
  }

  // Sucursales con productos
  Map<String, String> get _opcionesSucursal => {
        '': 'Todas las sucursales',
        for (final s in opcionesUnicas(_productos.map((p) => p.sucursal))) s: s,
      };

  // Rangos de precio del filtro
  static const Map<String, String> _opcionesPrecio = {
    '': 'Todos los precios',
    'p1': 'Hasta C\$ 25',
    'p2': 'C\$ 25 a C\$ 50',
    'p3': 'C\$ 50 a C\$ 100',
    'p4': 'Más de C\$ 100',
  };

  bool _enPrecio(double precio) => switch (_filtroPrecio) {
        'p1' => precio <= 25,
        'p2' => precio > 25 && precio <= 50,
        'p3' => precio > 50 && precio <= 100,
        'p4' => precio > 100,
        _ => true,
      };

  bool get _hayFiltros =>
      _filtroSucursal.isNotEmpty ||
      _filtroEstado.isNotEmpty ||
      _filtroCategoria.isNotEmpty ||
      _filtroPrecio.isNotEmpty ||
      _filtroDesde != null ||
      _filtroHasta != null;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      _filtroSucursal = '';
      _filtroEstado = '';
      _filtroCategoria = '';
      _filtroPrecio = '';
      _filtroDesde = null;
      _filtroHasta = null;
    });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final ProductosService _service = ProductosService();

  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;

  String _textoBusqueda = '';

  // Filtros desplegables
  String _filtroSucursal = '';
  String _filtroEstado = '';
  String _filtroCategoria = '';
  String _filtroPrecio = '';
  DateTime? _filtroDesde;
  DateTime? _filtroHasta;

  // Suscripción en tiempo real
  StreamSubscription<List<Producto>>? _sub;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _buscadorController.dispose();
    super.dispose();
  }

  void _suscribir() {
    _sub?.cancel();
    _sub = _service.streamProductos().listen(
      (lista) {
        if (!mounted) return;
        setState(() {
          _productos = lista;
          _cargando = false;
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _error = _mensajeError(e);
        });
      },
    );
  }

  List<Producto> get _productosFiltrados {
    final texto = _textoBusqueda.trim().toLowerCase();
    return _productos.where((p) {
      final coincideTexto = texto.isEmpty ||
          p.nombre.toLowerCase().contains(texto) ||
          p.codigo.toLowerCase().contains(texto);
      final coincideSucursal = _filtroSucursal.isEmpty ||
          _igualSucursal(p.sucursal, _filtroSucursal);
      final coincideEstado =
          _filtroEstado.isEmpty || p.estado == _filtroEstado;
      final coincideCategoria =
          _filtroCategoria.isEmpty || p.categoria.trim() == _filtroCategoria;
      final coincideFecha = fechaEnRango(p.fecha, _filtroDesde, _filtroHasta);
      return coincideTexto &&
          coincideSucursal &&
          coincideEstado &&
          coincideCategoria &&
          _enPrecio(p.precio) &&
          coincideFecha;
    }).toList();
  }

  Future<void> _nuevo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(
          service: _service,
          productos: _productos,
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(Producto producto) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleProductoScreen(
          producto: producto,
          service: _service,
          productos: _productos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _productosFiltrados;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.productos),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Productos',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registro de productos por categoría y sucursal',
                      style: TextStyle(fontSize: 13, color: _textoClaro),
                    ),
                    const SizedBox(height: 16),

                    // Buscador
                    TextField(
                      controller: _buscadorController,
                      onChanged: (v) => setState(() => _textoBusqueda = v),
                      decoration: _decoracionCampo(
                        hint: 'Buscar producto...',
                      ).copyWith(
                        prefixIcon:
                            Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
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
                          valor: _filtroSucursal,
                          opciones: _opcionesSucursal,
                          onChanged: (v) => setState(() => _filtroSucursal = v),
                        ),
                        FiltroDesplegable(
                          icono: Icons.toggle_on_outlined,
                          titulo: 'Estado',
                          valor: _filtroEstado,
                          opciones: const {
                            '': 'Todos los estados',
                            'Activo': 'Activo',
                            'Inactivo': 'Inactivo',
                          },
                          onChanged: (v) => setState(() => _filtroEstado = v),
                        ),
                        FiltroDesplegable(
                          icono: Icons.category_outlined,
                          titulo: 'Categoría',
                          valor: _filtroCategoria,
                          opciones: _opcionesCategoria,
                          onChanged: (v) => setState(() => _filtroCategoria = v),
                        ),
                        FiltroDesplegable(
                          icono: Icons.payments_outlined,
                          titulo: 'Precio',
                          valor: _filtroPrecio,
                          opciones: _opcionesPrecio,
                          onChanged: (v) => setState(() => _filtroPrecio = v),
                        ),
                        FiltroFecha(
                          etiqueta: 'Desde',
                          fecha: _filtroDesde,
                          maximo: _filtroHasta,
                          onChanged: (f) => setState(() => _filtroDesde = f),
                        ),
                        FiltroFecha(
                          etiqueta: 'Hasta',
                          fecha: _filtroHasta,
                          minimo: _filtroDesde,
                          onChanged: (f) => setState(() => _filtroHasta = f),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Botón nuevo (solo admin)
                    if (Permisos.instance.puedeEditarProductos)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _nuevo,
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

                    if (_cargando)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _colorAcento,
                          ),
                        ),
                      )
                    else if (_error != null)
                      _MensajeEstado(
                        icono: Icons.error_outline,
                        texto: 'Error al cargar productos: $_error',
                      )
                    else if (lista.isEmpty)
                      _MensajeEstado(
                        icono: Icons.inventory_2_outlined,
                        texto: _hayFiltros || _textoBusqueda.isNotEmpty
                            ? 'No hay productos con los filtros seleccionados.'
                            : Permisos.instance.puedeEditarProductos
                                ? 'No se encontraron productos.\n'
                                    'Toca "Nuevo" para registrar el primero.'
                                : 'No se encontraron productos.',
                      )
                    else
                      Column(
                        children: lista
                            .map(
                              (p) => _TarjetaProducto(
                                producto: p,
                                onTap: () => _abrirDetalle(p),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;

  const _TarjetaProducto({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                producto.nombre,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cantidad: ${producto.cantidad.toStringAsFixed(0)} en stock · ${producto.sucursal}',
                style: TextStyle(fontSize: 12, color: _textoClaro),
              ),
              Divider(height: 20, color: _colorBorde),
              Row(
                children: [
                  _EtiquetaEstado(activo: producto.estado == 'Activo'),
                  const SizedBox(width: 10),
                  Text(
                    _dinero(producto.precio),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _verde,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'REF: ${producto.codigo}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textoOscuro,
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
}

// Formulario de producto (nuevo y editar)

class ProductoFormScreen extends StatefulWidget {
  // null = crear producto nuevo
  final Producto? producto;
  final ProductosService service;

  // Para generar el siguiente código
  final List<Producto> productos;

  const ProductoFormScreen({
    super.key,
    required this.service,
    required this.productos,
    this.producto,
  });

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _precioController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _stockMinimoController;
  late String _estado;
  String? _sucursal; // nombre de la sucursal
  late List<Ingrediente> _ingredientes;
  bool _guardando = false;
  // Id del producto nuevo: el mismo en todos los intentos de guardado
  late final String _idAlta = widget.service.nuevoId();
  // Código reservado: se reutiliza si se reintenta el guardado
  String? _codigoAlta;
  String? _codigoAltaSucursal;

  final SucursalesService _sucursalesService = SucursalesService();
  final MateriaPrimaService _materiaPrimaService = MateriaPrimaService();
  late final Stream<List<Sucursal>> _sucursalesStream =
      _sucursalesService.streamSucursalesActivas();

  bool get _editando => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _categoriaController = TextEditingController(text: p?.categoria ?? '');
    _precioController = TextEditingController(
      text: p == null ? '' : p.precio.toString(),
    );
    _cantidadController = TextEditingController(
      text: p == null ? '' : p.cantidad.toString(),
    );
    _stockMinimoController = TextEditingController(
      text: p == null ? '' : p.stockMinimo.toString(),
    );
    _estado = (p != null && _kEstados.contains(p.estado))
        ? p.estado
        : _kEstados.first;
    _sucursal = (p != null && p.sucursal.isNotEmpty) ? p.sucursal : null;
    _ingredientes = p == null
        ? []
        : p.ingredientes
            .map((i) => Ingrediente(nombre: i.nombre, cantidad: i.cantidad))
            .toList();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _categoriaController.dispose();
    _precioController.dispose();
    _cantidadController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  double? _leerNumero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final precio = _leerNumero(_precioController);

    if (nombre.isEmpty) {
      _aviso('Ingrese el nombre del producto');
      return;
    }
    if (_precioController.text.trim().isEmpty || precio == null || precio < 0) {
      _aviso('Ingrese un precio válido');
      return;
    }
    if (_categoriaController.text.trim().isEmpty) {
      _aviso('Selecciona una categoría.');
      return;
    }
    if (_sucursal == null) {
      _aviso('Selecciona una sucursal.');
      return;
    }

    // Cantidad y stock mínimo obligatorios
    final cantidad = _leerNumero(_cantidadController);
    if (_cantidadController.text.trim().isEmpty ||
        cantidad == null ||
        cantidad < 0) {
      _aviso('Ingrese una cantidad válida.');
      return;
    }
    final stockMinimo = _leerNumero(_stockMinimoController);
    if (_stockMinimoController.text.trim().isEmpty ||
        stockMinimo == null ||
        stockMinimo <= 0) {
      _aviso('Ingrese un stock mínimo mayor a 0.');
      return;
    }
    // Al menos un ingrediente
    if (_ingredientes.isEmpty) {
      _aviso('Añade al menos un ingrediente.');
      return;
    }

    final categoria = _categoriaController.text.trim();

    if (_guardando) return; // ignora toques repetidos
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    // Ingredientes descontados al crear el producto
    var consumos = <ConsumoIngrediente>[];
    try {
      if (_editando) {
        final original = widget.producto!;
        if (original.id == null) {
          throw Exception('No se encontró el producto para actualizar');
        }

        // Copia: se aplica si Firestore responde bien
        final actualizado = Producto(
          id: original.id,
          codigo: original.codigo,
          nombre: nombre,
          categoria: categoria,
          precio: precio,
          cantidad: cantidad,
          stockMinimo: stockMinimo,
          estado: _estado,
          sucursal: _sucursal!,
          ingredientes: List.from(_ingredientes),
        );
        consumos = await widget.service.actualizarProductoConIngredientes(
          actualizado,
          cantidadAnterior: original.cantidad,
        );

        // Cambios para la auditoría
        final cambios = <String>[
          if (original.nombre != actualizado.nombre)
            'Nombre: ${original.nombre} → ${actualizado.nombre}',
          if (original.categoria != actualizado.categoria)
            'Categoría: ${original.categoria} → ${actualizado.categoria}',
          if (original.precio != actualizado.precio)
            'Precio: ${original.precio} → ${actualizado.precio}',
          if (original.cantidad != actualizado.cantidad)
            'Cantidad: ${original.cantidad} → ${actualizado.cantidad}',
          if (original.stockMinimo != actualizado.stockMinimo)
            'Stock mínimo: ${original.stockMinimo} → ${actualizado.stockMinimo}',
          if (original.estado != actualizado.estado)
            'Estado: ${original.estado} → ${actualizado.estado}',
          if (original.sucursal != actualizado.sucursal)
            'Sucursal: ${original.sucursal} → ${actualizado.sucursal}',
        ];
        final detalleAuditoria = <String>[
          ...cambios,
          if (consumos.isNotEmpty)
            'Ingredientes descontados: ${consumos.map((c) => c.resumen).join(' · ')}',
        ];
        _auditarProducto(
          TipoEvento.editar,
          'Producto "${actualizado.nombre}" actualizado',
          actualizado,
          detalle: detalleAuditoria.isEmpty ? null : detalleAuditoria.join(' · '),
        );

        original
          ..nombre = actualizado.nombre
          ..categoria = actualizado.categoria
          ..precio = actualizado.precio
          ..cantidad = actualizado.cantidad
          ..stockMinimo = actualizado.stockMinimo
          ..estado = actualizado.estado
          ..sucursal = actualizado.sucursal
          ..ingredientes = actualizado.ingredientes;
      } else {
        // Código con el prefijo de la sucursal elegida (N001, S001...)
        if (_codigoAlta == null || _codigoAltaSucursal != _sucursal) {
          _codigoAlta = await widget.service.siguienteCodigo(_sucursal!);
          _codigoAltaSucursal = _sucursal;
        }
        final codigoNuevo = _codigoAlta!;
        final nuevo = Producto(
          codigo: codigoNuevo,
          nombre: nombre,
          categoria: categoria,
          precio: precio,
          cantidad: cantidad,
          stockMinimo: stockMinimo,
          estado: _estado,
          sucursal: _sucursal!,
          ingredientes: List.from(_ingredientes),
        );
        final alta = await widget.service
            .agregarProductoConIngredientes(nuevo, id: _idAlta);
        nuevo.id = alta.id;
        consumos = alta.consumos;
        _auditarProducto(
          TipoEvento.crear,
          'Producto "${nuevo.nombre}" creado',
          nuevo,
          detalle: consumos.isEmpty
              ? null
              : 'Ingredientes descontados: ${consumos.map((c) => c.resumen).join(' · ')}',
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            consumos.isNotEmpty
                ? '${_editando ? 'Producto actualizado' : 'Producto guardado'}. Se descontaron los ingredientes del stock.'
                : _editando
                    ? 'Producto actualizado correctamente'
                    : 'Producto guardado correctamente',
          ),
        ),
      );
    } on ProductoDuplicadoException {
      // El primer toque sí se guardó: se cierra sin duplicar
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Este producto ya estaba registrado. No se guardó otra vez.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      final texto = _mensajeError(e);
      if (texto.startsWith('No hay suficientes ingredientes')) {
        // Sin stock de ingredientes: el formulario queda abierto
        _aviso('$texto Baja la cantidad o registra una entrada en Ingredientes.');
      } else {
        _aviso('No se pudo guardar: $texto');
      }
    }
  }

  // Unidades que se van a producir al guardar: al editar solo cuenta lo que
  // aumenta la cantidad, al crear cuenta toda
  double _unidadesAProducir() {
    final cantidad = _leerNumero(_cantidadController) ?? 0;
    final anterior = _editando ? widget.producto!.cantidad : 0.0;
    final unidades = cantidad - anterior;
    return unidades < 0 ? 0 : unidades;
  }

  // Cuánto de un ingrediente (en la unidad de su stock) ya piden los que están
  // agregados en la lista, por unidad de producto
  double _yaUsadoDe(MateriaPrima materia) {
    var total = 0.0;
    for (final i in _ingredientes) {
      if (i.nombre.trim().toLowerCase() != materia.nombre.trim().toLowerCase()) {
        continue;
      }
      final c = leerCantidadReceta(i.cantidad);
      if (c == null) continue;
      total += convertirUnidad(c.valor, c.unidad, materia.unidadMedida) ?? 0;
    }
    return total;
  }

  // Agregar ingrediente

  void _agregarIngrediente() {
    MateriaPrima? materiaSeleccionada;
    // Unidad de la receta (puede ser distinta a la del stock)
    String? unidadSeleccionada;
    final cantidad = TextEditingController();
    String? errorIngrediente;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Apariencia.instance.superficie,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Añadir ingrediente',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              content: StreamBuilder<List<MateriaPrima>>(
                stream: _materiaPrimaService.streamMateriasPrimas(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Error al cargar ingredientes: ${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: _rojo),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: LinearProgressIndicator(color: _colorAcento),
                    );
                  }

                  // Solo ingredientes de la sucursal del producto
                  final sucursalProducto = _sucursal;
                  if (sucursalProducto == null) {
                    return Text(
                      'Selecciona primero la sucursal del producto.',
                      style: TextStyle(color: _textoClaro),
                    );
                  }
                  final materias = snapshot.data!
                      .where((m) =>
                          m.activo && _igualSucursal(m.sucursal, sucursalProducto))
                      .toList();

                  if (materias.isEmpty) {
                    return Text(
                      'No hay ingredientes activos en $sucursalProducto.',
                      style: TextStyle(color: _textoClaro),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _etiqueta('Ingrediente'),
                      DropdownButtonFormField<String>(
                        initialValue: materiaSeleccionada?.id,
                        isExpanded: true,
                        hint: const Text('Seleccionar'),
                        decoration: _decoracionCampo(),
                        items: materias.map((materia) {
                          return DropdownMenuItem<String>(
                            value: materia.id,
                            child: Text(
                              '${materia.nombre} · ${materia.cantidadConUnidad}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            materiaSeleccionada = materias.firstWhere(
                              (materia) => materia.id == value,
                            );
                            // Empieza con la unidad del stock
                            unidadSeleccionada =
                                materiaSeleccionada!.unidadMedida;
                            errorIngrediente = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Cantidad por cada unidad de producto'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cantidad,
                              // Solo números (con un separador decimal)
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                TextInputFormatter.withFunction(
                                  (anterior, nuevo) => RegExp(r'^\d*[.,]?\d*$')
                                          .hasMatch(nuevo.text)
                                      ? nuevo
                                      : anterior,
                                ),
                              ],
                              onChanged: (_) {
                                if (errorIngrediente != null) {
                                  setDialogState(() => errorIngrediente = null);
                                }
                              },
                              decoration: _decoracionCampo(
                                hint: 'Ejemplo: 10',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Unidades del mismo tipo que el ingrediente (lt -> lt, ml)
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(materiaSeleccionada?.id),
                              initialValue: unidadSeleccionada,
                              isExpanded: true,
                              decoration: _decoracionCampo(),
                              items: (materiaSeleccionada == null
                                      ? <String>[]
                                      : unidadesCompatibles(
                                          materiaSeleccionada!.unidadMedida,
                                        ))
                                  .map(
                                    (u) => DropdownMenuItem<String>(
                                      value: u,
                                      child: Text(u),
                                    ),
                                  )
                                  .toList(),
                              onChanged: materiaSeleccionada == null
                                  ? null
                                  : (v) => setDialogState(
                                        () => unidadSeleccionada = v,
                                      ),
                            ),
                          ),
                        ],
                      ),
                      if (materiaSeleccionada != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Disponible: ${materiaSeleccionada!.cantidadConUnidad}',
                            style: TextStyle(fontSize: 12, color: _textoClaro),
                          ),
                        ),
                      if (errorIngrediente != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            errorIngrediente!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _rojo,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: _textoOscuro),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (materiaSeleccionada == null) {
                      setDialogState(
                        () => errorIngrediente = 'Selecciona un ingrediente.',
                      );
                      return;
                    }
                    final valor = double.tryParse(
                      cantidad.text.trim().replaceAll(',', '.'),
                    );
                    if (valor == null || valor <= 0) {
                      setDialogState(
                        () => errorIngrediente =
                            'Escribe una cantidad numérica mayor a 0.',
                      );
                      return;
                    }

                    // Revisa que alcance el stock del ingrediente
                    final unidades = _unidadesAProducir();
                    if (unidades > 0) {
                      final enStock = convertirUnidad(
                        valor,
                        unidadSeleccionada ?? materiaSeleccionada!.unidadMedida,
                        materiaSeleccionada!.unidadMedida,
                      );
                      if (enStock != null) {
                        final necesario = redondearCantidad(
                          (enStock + _yaUsadoDe(materiaSeleccionada!)) * unidades,
                        );
                        final disponible = materiaSeleccionada!.cantidad;
                        if (necesario > disponible + 1e-9) {
                          final u = materiaSeleccionada!.unidadMedida.toLowerCase();
                          setDialogState(
                            () => errorIngrediente = disponible <= 0
                                ? 'Stock insuficiente: \"${materiaSeleccionada!.nombre}\" está agotado.'
                                : 'Stock insuficiente de \"${materiaSeleccionada!.nombre}\": '
                                    'disponible ${formatearCantidad(disponible)} $u, '
                                    'se necesitan ${formatearCantidad(necesario)} $u '
                                    'para ${formatearCantidad(unidades)} unidades.',
                          );
                          return;
                        }
                      }
                    }

                    final numero = valor == valor.roundToDouble()
                        ? valor.toInt().toString()
                        : valor.toString();

                    setState(() {
                      _ingredientes.add(
                        Ingrediente(
                          nombre: materiaSeleccionada!.nombre,
                          // Se guarda como "10 ml" (número + unidad)
                          cantidad:
                              '$numero ${unidadSeleccionada ?? materiaSeleccionada!.unidadMedida}',
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _etiqueta(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          texto,
          style: TextStyle(fontSize: 12, color: _textoClaro),
        ),
      );

  Widget _campoTexto({
    required String etiqueta,
    required TextEditingController controller,
    required String hint,
    TextInputType teclado = TextInputType.text,
    TextCapitalization capitalizacion = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(etiqueta),
        TextField(
          controller: controller,
          keyboardType: teclado,
          textCapitalization: capitalizacion,
          decoration: _decoracionCampo(hint: hint),
        ),
      ],
    );
  }

  // Selector de categoría (lista predeterminada)
  Widget _campoCategoria() {
    final actual = _categoriaController.text.trim();
    final opciones = [...kCategoriasProducto];
    // Conserva categorías antiguas escritas a mano al editar un producto
    if (actual.isNotEmpty && !opciones.contains(actual)) {
      opciones.add(actual);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('Categoría'),
        DropdownButtonFormField<String>(
          initialValue: actual.isEmpty ? null : actual,
          isExpanded: true,
          hint: const Text('Seleccionar'),
          items: opciones
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _categoriaController.text = v ?? ''),
          decoration: _decoracionCampo(),
        ),
      ],
    );
  }

  // Selector de sucursal
  Widget _campoSucursal() {
    return StreamBuilder<List<Sucursal>>(
      stream: _sucursalesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error al leer sucursales: ${snapshot.error}',
            style: const TextStyle(fontSize: 12, color: _rojo),
          );
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: LinearProgressIndicator(color: _colorAcento),
          );
        }

        final nombres = snapshot.data!.map((s) => s.nombre).toList();
        if (_sucursal != null && !nombres.contains(_sucursal)) {
          nombres.add(_sucursal!);
        }

        if (nombres.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Apariencia.instance.aviso,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No hay sucursales activas. Registra una en el módulo '
              'Sucursales (menú lateral) para poder continuar.',
              style: TextStyle(fontSize: 12, color: _textoOscuro),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: _sucursal,
          isExpanded: true,
          hint: const Text('Seleccionar'),
          items: nombres
              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
              .toList(),
          onChanged: (v) => setState(() => _sucursal = v),
          decoration: _decoracionCampo(),
        );
      },
    );
  }

  Widget _listaIngredientes() {
    if (_ingredientes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _fondoInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _colorBorde),
        ),
        child: Text(
          'No hay ingredientes agregados',
          style: TextStyle(fontSize: 13, color: _textoClaro),
        ),
      );
    }

    return Column(
      children: _ingredientes.map((ingrediente) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colorBorde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ingrediente.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textoOscuro,
                  ),
                ),
              ),
              Text(
                ingrediente.cantidad,
                style: TextStyle(fontSize: 13, color: _textoClaro),
              ),
              IconButton(
                onPressed: _guardando
                    ? null
                    : () => setState(() => _ingredientes.remove(ingrediente)),
                icon: const Icon(Icons.delete_outline, size: 20, color: _rojo),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: Text(
                  'Productos',
                  style: TextStyle(color: _textoOscuro),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _editando ? 'Editar producto' : 'Nuevo producto',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textoOscuro,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              _campoTexto(
                etiqueta: 'Nombre',
                controller: _nombreController,
                hint: 'Escribir nombre',
                capitalizacion: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              _campoCategoria(),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campoTexto(
                      etiqueta: 'Precio',
                      controller: _precioController,
                      hint: '0,00',
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campoTexto(
                      etiqueta: 'Cantidad',
                      controller: _cantidadController,
                      hint: '0,00',
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _campoTexto(
                      etiqueta: 'Stock mínimo',
                      controller: _stockMinimoController,
                      hint: '0,00',
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Estado'),
                        DropdownButtonFormField<String>(
                          initialValue: _estado,
                          isExpanded: true,
                          items: _kEstados
                              .map(
                                (e) => DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _estado = v);
                          },
                          decoration: _decoracionCampo(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _etiqueta('Sucursal'),
              _campoSucursal(),
              const SizedBox(height: 22),

              Text(
                'Ingredientes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 10),
              _listaIngredientes(),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _guardando ? null : _agregarIngrediente,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _ingredientes.isEmpty
                        ? 'Añadir ingrediente'
                        : 'Añadir otro ingrediente',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _colorAcento,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _colorAcento.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_editando ? 'GUARDAR CAMBIOS' : 'GUARDAR'),
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
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textoOscuro,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _textoOscuro),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Detalle de producto

class DetalleProductoScreen extends StatefulWidget {
  final Producto producto;
  final ProductosService service;
  final List<Producto> productos;

  const DetalleProductoScreen({
    super.key,
    required this.producto,
    required this.service,
    required this.productos,
  });

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  bool _procesando = false;

  Producto get _producto => widget.producto;
  bool get _activo => _producto.estado == 'Activo';

  Future<void> _editar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(
          service: widget.service,
          productos: widget.productos,
          producto: _producto,
        ),
      ),
    );
    // El formulario ya actualizó el objeto
    if (mounted) setState(() {});
  }

  // Pregunta qué hacer con el stock al desactivar un producto
  Future<_DecisionDesactivar?> _preguntarDesactivar() async {
    final unidades = _producto.cantidad;
    final cantidadTxt = unidades == unidades.roundToDouble()
        ? unidades.toInt().toString()
        : unidades.toString();
    const motivos = ['Vencido', 'Dañado', 'Otro'];
    final detalleController = TextEditingController();
    var darDeBaja = false;
    var motivo = motivos.first;
    String? error;

    final resultado = await showDialog<_DecisionDesactivar>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget opcion({
              required bool valor,
              required String titulo,
              required String texto,
            }) {
              final seleccionada = darDeBaja == valor;
              return InkWell(
                onTap: () => setStateDialog(() {
                  darDeBaja = valor;
                  error = null;
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: seleccionada
                        ? _colorAcento.withValues(alpha: 0.10)
                        : _fondoInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: seleccionada ? _colorAcento : _colorBorde,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        seleccionada
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: seleccionada ? _colorAcento : _textoClaro,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textoOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              texto,
                              style: TextStyle(
                                fontSize: 12,
                                color: _textoClaro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Apariencia.instance.superficie,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Desactivar producto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '"${_producto.nombre}" tiene $cantidadTxt unidades en '
                      'stock. ¿Qué hacemos con ellas?',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textoClaro,
                      ),
                    ),
                    const SizedBox(height: 12),
                    opcion(
                      valor: false,
                      titulo: 'Solo desactivar',
                      texto: 'El stock se conserva y no se podrá vender. '
                          'Al reactivarlo, sigue ahí.',
                    ),
                    const SizedBox(height: 8),
                    opcion(
                      valor: true,
                      titulo: 'Desactivar y dar de baja',
                      texto: 'El stock pasa a 0 y queda registrado como '
                          'merma, con su motivo.',
                    ),
                    if (darDeBaja) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: motivo,
                        isExpanded: true,
                        items: motivos
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setStateDialog(() {
                              motivo = v;
                              error = null;
                            });
                          }
                        },
                        decoration: _decoracionCampo(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detalleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoracionCampo(
                          hint: motivo == 'Otro'
                              ? 'Explica el motivo'
                              : 'Detalle (opcional)',
                        ),
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(fontSize: 12, color: _rojo),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(foregroundColor: _textoClaro),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final detalle = detalleController.text.trim();
                    if (darDeBaja && motivo == 'Otro' && detalle.isEmpty) {
                      setStateDialog(
                        () => error = 'Explica el motivo de la baja.',
                      );
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _DecisionDesactivar(
                        darDeBaja: darDeBaja,
                        motivo: !darDeBaja
                            ? ''
                            : (detalle.isEmpty ? motivo : '$motivo - $detalle'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );
    Future.delayed(
      const Duration(milliseconds: 600),
      detalleController.dispose,
    );
    return resultado;
  }

  Future<void> _cambiarEstado() async {
    final id = _producto.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no tiene ID de Firestore'),
        ),
      );
      return;
    }

    final nuevoEstado = _activo ? 'Inactivo' : 'Activo';

    // Si tiene stock, se pregunta qué hacer con las unidades
    var darDeBaja = false;
    var motivoBaja = '';
    final unidades = _producto.cantidad;
    if (nuevoEstado == 'Inactivo' && unidades > 0) {
      final decision = await _preguntarDesactivar();
      if (decision == null || !mounted) return; // cancelado
      darDeBaja = decision.darDeBaja;
      motivoBaja = decision.motivo;
    }
    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final estadoAnterior = _producto.estado;
      if (darDeBaja) {
        await widget.service.desactivarConMerma(id: id, motivo: motivoBaja);
      } else {
        await widget.service.cambiarEstado(id, nuevoEstado);
      }
      _auditarProducto(
        TipoEvento.editar,
        nuevoEstado == 'Activo'
            ? 'Producto "${_producto.nombre}" activado'
            : 'Producto "${_producto.nombre}" desactivado',
        _producto,
        detalle: darDeBaja
            ? 'Estado: $estadoAnterior → $nuevoEstado · Merma de '
                '${unidades == unidades.roundToDouble() ? unidades.toInt() : unidades} '
                'unidades ($motivoBaja)'
            : 'Estado: $estadoAnterior → $nuevoEstado',
      );
      if (!mounted) return;
      setState(() {
        _producto.estado = nuevoEstado;
        if (darDeBaja) _producto.cantidad = 0;
        _procesando = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'Activo'
                ? 'Producto activado'
                : (darDeBaja
                    ? 'Producto desactivado y stock dado de baja'
                    : 'Producto desactivado'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: ${_mensajeError(e)}'),
        ),
      );
    }
  }

  Future<void> _eliminar() async {
    final id = _producto.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no tiene ID de Firestore'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que quieres eliminar "${_producto.nombre}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: _rojo),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    if (_procesando) return; // ignora toques repetidos
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminarProducto(id);
      _auditarProducto(
        TipoEvento.eliminar,
        'Producto "${_producto.nombre}" eliminado',
        _producto,
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Producto eliminado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${_mensajeError(e)}')),
      );
    }
  }

  Widget _tituloSeccion(String texto) => Text(
        texto,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _textoOscuro,
        ),
      );

  BoxDecoration get _decoracionTarjeta => BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorBorde),
      );

  @override
  Widget build(BuildContext context) {
    final p = _producto;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: Text(
                  'Productos',
                  style: TextStyle(color: _textoOscuro),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
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
                          Text(
                            'Producto',
                            style: TextStyle(fontSize: 12, color: _textoClaro),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.nombre,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _textoOscuro,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _EtiquetaEstado(activo: _activo),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dinero(p.precio),
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
                    _FilaInfo('Código', p.codigo),
                    _FilaInfo('Nombre del producto', p.nombre),
                    _FilaInfo('Categoría', p.categoria),
                    _FilaInfo('Precio', _dinero(p.precio)),
                    _FilaInfo('Stock actual', p.cantidad.toStringAsFixed(0)),
                    _FilaInfo('Stock mínimo', p.stockMinimo.toStringAsFixed(0)),
                    _FilaInfo('Sucursal', p.sucursal),
                    _FilaInfo('Estado', p.estado, ultima: true),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              _tituloSeccion('Ingredientes'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: _decoracionTarjeta,
                child: p.ingredientes.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Este producto no tiene ingredientes registrados.',
                          style: TextStyle(fontSize: 13, color: _textoClaro),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < p.ingredientes.length; i++)
                            _FilaInfo(
                              p.ingredientes[i].nombre,
                              p.ingredientes[i].cantidad,
                              ultima: i == p.ingredientes.length - 1,
                            ),
                        ],
                      ),
              ),
              // Solo el admin edita
              if (Permisos.instance.puedeEditarProductos) ...[
              const SizedBox(height: 22),

              _tituloSeccion('Acciones'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _procesando ? null : _editar,
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
                onPressed: _procesando ? null : _eliminar,
              ),
              const SizedBox(height: 10),
              _BotonContorno(
                texto: _activo ? 'Desactivar' : 'Activar',
                icono: _activo
                    ? Icons.pause_circle_outline
                    : Icons.check_circle_outline,
                color: _colorAcento,
                onPressed: _procesando ? null : _cambiarEstado,
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Resultado del diálogo de desactivar con stock
class _DecisionDesactivar {
  final bool darDeBaja;
  final String motivo;
  const _DecisionDesactivar({required this.darDeBaja, required this.motivo});
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
        children: [
          Expanded(
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