import 'package:flutter/material.dart';

import '../../Chino/modelos/materia_prima_modelo.dart';
import '../../Chino/controladores/materia_prima_service.dart';
import '../../Chino/vistas/AppDrawer.dart';
import '../../Henry/modelos/sucursal_modelo.dart';
import '../../Henry/controladores/sucursales_service.dart';
import '../modelos/productos_modelos.dart';
import '../controladores/productos_service.dart';

// Mismos colores y estilos que usan Materia Prima, Stock, Reportes y
// Sucursales, para que todos los CRUDs se vean igual.
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);
const Color _verde = Color(0xFF1F7A3D);
const Color _rojo = Color(0xFFB3261E);

const List<String> _kEstados = ['Activo', 'Inactivo'];

/// Convierte una excepción en un texto corto para mostrar en un SnackBar.
String _mensajeError(Object e) => e
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '');

InputDecoration _decoracionCampo({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: _fondoInput,
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

String _dinero(double valor) => 'C\$ ${valor.toStringAsFixed(2)}';

// ---------------------------------------------------------------------------
// 1. Lista de Productos (pantalla principal del módulo, con menú lateral)
// ---------------------------------------------------------------------------

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  static const List<String> _filtros = [
    'Todos',
    'Activos',
    'Inactivos',
    'Repostería',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final ProductosService _service = ProductosService();

  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;

  String _filtroSeleccionado = 'Todos';
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final lista = await _service.obtenerProductos();
      if (!mounted) return;
      setState(() {
        _productos = lista;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = _mensajeError(e);
      });
    }
  }

  List<Producto> get _productosFiltrados {
    final texto = _textoBusqueda.trim().toLowerCase();
    return _productos.where((p) {
      final coincideTexto = texto.isEmpty ||
          p.nombre.toLowerCase().contains(texto) ||
          p.codigo.toLowerCase().contains(texto);
      final coincideFiltro = switch (_filtroSeleccionado) {
        'Todos' => true,
        'Activos' => p.estado == 'Activo',
        'Inactivos' => p.estado == 'Inactivo',
        _ => p.categoria == _filtroSeleccionado,
      };
      return coincideTexto && coincideFiltro;
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
    _cargar();
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
    _cargar();
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
                    const Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
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
                            const Icon(Icons.search, color: _textoClaro),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filtros tipo pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filtros.map((filtro) {
                        final seleccionado = _filtroSeleccionado == filtro;
                        return ChoiceChip(
                          label: Text(filtro),
                          selected: seleccionado,
                          onSelected: (_) =>
                              setState(() => _filtroSeleccionado = filtro),
                          labelStyle: TextStyle(
                            color: seleccionado ? Colors.white : _textoOscuro,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          selectedColor: _colorAcento,
                          backgroundColor: _fondoInput,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  seleccionado ? _colorAcento : _colorBorde,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Botón Nuevo
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
                    const Text(
                      'Listado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textoOscuro,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_cargando)
                      const Padding(
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
                      const _MensajeEstado(
                        icono: Icons.inventory_2_outlined,
                        texto: 'No se encontraron productos.\n'
                            'Toca "Nuevo" para registrar el primero.',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cantidad: ${producto.cantidad.toStringAsFixed(0)} en stock · ${producto.sucursal}',
                style: const TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const Divider(height: 20, color: _colorBorde),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textoOscuro,
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
}

// ---------------------------------------------------------------------------
// 2 y 4. Nuevo producto / Editar producto (mismo formulario)
// ---------------------------------------------------------------------------

class ProductoFormScreen extends StatefulWidget {
  /// Si es `null` el formulario crea un producto nuevo; si trae uno, lo edita.
  final Producto? producto;
  final ProductosService service;

  /// Lista actual de productos, solo se usa para generar el siguiente código.
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
  String? _sucursal; // nombre de la sucursal (viene de Firestore)
  late List<Ingrediente> _ingredientes;
  bool _guardando = false;

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

  /// Siguiente código libre (P001, P002...), igual que antes.
  String _generarCodigo() {
    int mayor = 0;
    for (final producto in widget.productos) {
      final numero = int.tryParse(producto.codigo.replaceFirst('P', ''));
      if (numero != null && numero > mayor) mayor = numero;
    }
    return 'P${(mayor + 1).toString().padLeft(3, '0')}';
  }

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
    if (_sucursal == null) {
      _aviso('Selecciona una sucursal.');
      return;
    }

    final categoria = _categoriaController.text.trim().isEmpty
        ? 'Pan'
        : _categoriaController.text.trim();
    final cantidad = _leerNumero(_cantidadController) ?? 0;
    final stockMinimo = _leerNumero(_stockMinimoController) ?? 0;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_editando) {
        final original = widget.producto!;
        if (original.id == null) {
          throw Exception('No se encontró el producto para actualizar');
        }

        // Se guarda una copia y solo si Firestore responde bien se actualiza
        // el objeto original (así la pantalla de detalle se refresca).
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
        await widget.service.actualizarProducto(actualizado);

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
        final nuevo = Producto(
          codigo: _generarCodigo(),
          nombre: nombre,
          categoria: categoria,
          precio: precio,
          cantidad: cantidad,
          stockMinimo: stockMinimo,
          estado: _estado,
          sucursal: _sucursal!,
          ingredientes: List.from(_ingredientes),
        );
        nuevo.id = await widget.service.agregarProducto(nuevo);
      }

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Producto actualizado correctamente'
                : 'Producto guardado correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo guardar: ${_mensajeError(e)}');
    }
  }

  // AÑADIR INGREDIENTE (se eligen de la materia prima activa)

  void _agregarIngrediente() {
    MateriaPrima? materiaSeleccionada;
    final cantidad = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
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
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: LinearProgressIndicator(color: _colorAcento),
                    );
                  }

                  final materias =
                      snapshot.data!.where((m) => m.activo).toList();

                  if (materias.isEmpty) {
                    return const Text(
                      'No hay ingredientes activos registrados.',
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
                              '${materia.nombre} (${materia.unidadMedida})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            materiaSeleccionada = materias.firstWhere(
                              (materia) => materia.id == value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Cantidad'),
                      TextField(
                        controller: cantidad,
                        decoration: _decoracionCampo(
                          hint: materiaSeleccionada == null
                              ? 'Ejemplo: 500 g'
                              : 'Ejemplo: 500 ${materiaSeleccionada!.unidadMedida}',
                        ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _textoOscuro),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (materiaSeleccionada == null) return;
                    if (cantidad.text.trim().isEmpty) return;

                    setState(() {
                      _ingredientes.add(
                        Ingrediente(
                          nombre: materiaSeleccionada!.nombre,
                          cantidad: cantidad.text.trim(),
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
          style: const TextStyle(fontSize: 12, color: _textoClaro),
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

  /// Selector de sucursal alimentado por Firestore (`sucursales`, solo las
  /// activas). Si el producto que se edita apunta a una sucursal que ya no
  /// está activa, se conserva en la lista para no perder el dato.
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
          return const Padding(
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
              color: const Color(0xFFFFF1D2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
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
        child: const Text(
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colorBorde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ingrediente.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textoOscuro,
                  ),
                ),
              ),
              Text(
                ingrediente.cantidad,
                style: const TextStyle(fontSize: 13, color: _textoClaro),
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
                icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: const Text(
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
                  style: const TextStyle(
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

              _campoTexto(
                etiqueta: 'Categoría',
                controller: _categoriaController,
                hint: 'Ej. Pan, Repostería',
                capitalizacion: TextCapitalization.sentences,
              ),
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

              const Text(
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
                    side: const BorderSide(color: _textoOscuro),
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

// ---------------------------------------------------------------------------
// 3. Información del producto (detalle + acciones Editar / Eliminar / Desactivar)
// ---------------------------------------------------------------------------

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
    // El formulario actualiza el objeto al guardar: solo se redibuja.
    if (mounted) setState(() {});
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
    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.cambiarEstado(id, nuevoEstado);
      if (!mounted) return;
      setState(() {
        _producto.estado = nuevoEstado;
        _procesando = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'Activo'
                ? 'Producto activado'
                : 'Producto desactivado',
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

    setState(() => _procesando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.eliminarProducto(id);
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
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _textoOscuro,
        ),
      );

  BoxDecoration get _decoracionTarjeta => BoxDecoration(
        color: Colors.white,
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
                icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: const Text(
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
                          const Text(
                            'Producto',
                            style: TextStyle(fontSize: 12, color: _textoClaro),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.nombre,
                            style: const TextStyle(
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
                    ? const Padding(
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
          ),
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
        children: [
          Expanded(
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