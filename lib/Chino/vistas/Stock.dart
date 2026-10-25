import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'AppDrawer.dart';
import '../modelos/producto_modelo.dart';
import '../modelos/materia_prima_modelo.dart';
import '../controladores/materia_prima_service.dart';
import '../controladores/productos_service.dart';
import '../controladores/stock_service.dart';
import '../controladores/permisos_service.dart';
import '../controladores/apariencia_service.dart';
import 'filtros_comunes.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;

// Pantalla de inventario
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final ProductosService _productosService = ProductosService();
  final StockService _stockService = StockService();
  final MateriaPrimaService _materiaService = MateriaPrimaService();
  late final Stream<List<MateriaPrima>> _materiasStream =
      _materiaService.streamMateriasPrimas();

  // Sección abierta: 'Productos' o 'Ingredientes'
  String _seccion = 'Productos';

  // Misma conexión para la lista y para las opciones de los filtros
  late final Stream<List<Producto>> _productosStream =
      _productosService.streamProductos();

  String _textoBusqueda = '';

  // Filtros desplegables (se reinician al cambiar de sección)
  String _filtroSucursal = '';
  String _filtroEstado = '';
  String _filtroCategoria = '';
  String _filtroStock = '';

  // Productos con un ajuste en curso
  final Set<String> _ajustando = {};

  bool get _hayFiltros =>
      _filtroSucursal.isNotEmpty ||
      _filtroEstado.isNotEmpty ||
      _filtroCategoria.isNotEmpty ||
      _filtroStock.isNotEmpty;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      _filtroSucursal = '';
      _filtroEstado = '';
      _filtroCategoria = '';
      _filtroStock = '';
    });
  }

  bool _mismaSucursal(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  bool _coincideEstado(bool activo) =>
      _filtroEstado.isEmpty ||
      (_filtroEstado == 'Activo' && activo) ||
      (_filtroEstado == 'Inactivo' && !activo);

  List<Producto> _filtrar(List<Producto> productos) {
    return productos.where((p) {
      final coincideTexto = p.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
      final coincideSucursal =
          _filtroSucursal.isEmpty || _mismaSucursal(p.sucursal, _filtroSucursal);
      final coincideCategoria =
          _filtroCategoria.isEmpty || p.categoria.trim() == _filtroCategoria;
      // Agotado: sin stock. Bajo: queda poco (hasta su mínimo)
      final coincideStock = switch (_filtroStock) {
        'agotado' => p.stock <= 0,
        'bajo' => p.stock > 0 && p.stock <= p.stockMinimo,
        'disponible' => p.stock > p.stockMinimo,
        _ => true,
      };
      return coincideTexto &&
          coincideSucursal &&
          _coincideEstado(p.activo) &&
          coincideCategoria &&
          coincideStock;
    }).toList();
  }

  // Barra de filtros con las opciones de la sección abierta
  Widget _barraFiltros() {
    Widget barra({
      required Iterable<String> sucursales,
      required Iterable<String> categorias,
      required bool conStockBajo,
    }) {
      return BarraFiltros(
        hayFiltros: _hayFiltros,
        onLimpiar: _quitarFiltros,
        filtros: [
          FiltroDesplegable(
            icono: Icons.storefront_outlined,
            titulo: 'Sucursal',
            valor: _filtroSucursal,
            opciones: {
              '': 'Todas las sucursales',
              for (final s in opcionesUnicas(sucursales)) s: s,
            },
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
            opciones: {
              '': 'Todas las categorías',
              for (final c in opcionesUnicas(categorias)) c: c,
            },
            onChanged: (v) => setState(() => _filtroCategoria = v),
          ),
          FiltroDesplegable(
            icono: Icons.inventory_2_outlined,
            titulo: 'Stock',
            valor: _filtroStock,
            opciones: {
              '': 'Todo el stock',
              'disponible': 'Disponible',
              if (conStockBajo) 'bajo': 'Stock bajo',
              'agotado': 'Agotado',
            },
            onChanged: (v) => setState(() => _filtroStock = v),
          ),
        ],
      );
    }

    if (_seccion == 'Productos') {
      return StreamBuilder<List<Producto>>(
        stream: _productosStream,
        builder: (context, snapshot) {
          final datos = snapshot.data ?? const <Producto>[];
          return barra(
            sucursales: datos.map((p) => p.sucursal),
            categorias: datos.map((p) => p.categoria),
            conStockBajo: true,
          );
        },
      );
    }
    return StreamBuilder<List<MateriaPrima>>(
      stream: _materiasStream,
      builder: (context, snapshot) {
        final datos = snapshot.data ?? const <MateriaPrima>[];
        return barra(
          sucursales: datos.map((m) => m.sucursal),
          categorias: datos.map((m) => m.categoria),
          conStockBajo: false,
        );
      },
    );
  }

  // Ajustar el stock de un ingrediente
  Future<void> _abrirAjusteIngrediente(MateriaPrima materia) async {
    // El vendedor solo ajusta su sucursal
    if (!Permisos.instance.puedeAjustarStock(materia.sucursal)) {
      avisarSinPermiso(
        context,
        'Solo puedes ajustar el stock de tu sucursal.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AjustarIngredienteScreen(
          materia: materia,
          stockService: _stockService,
        ),
      ),
    );
  }

  // Ingredientes en vivo
  Widget _listaIngredientes() {
    return StreamBuilder<List<MateriaPrima>>(
      stream: _materiasStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MensajeEstado(
            icono: Icons.error_outline,
            texto: 'Error al leer ingredientes: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: _colorAcento)),
          );
        }

        final lista = snapshot.data!.where((m) {
          final coincideTexto =
              m.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
          final coincideSucursal = _filtroSucursal.isEmpty ||
              _mismaSucursal(m.sucursal, _filtroSucursal);
          final coincideCategoria =
              _filtroCategoria.isEmpty || m.categoria == _filtroCategoria;
          final coincideStock = switch (_filtroStock) {
            'agotado' => m.agotado,
            'disponible' => !m.agotado,
            _ => true,
          };
          return coincideTexto &&
              coincideSucursal &&
              _coincideEstado(m.activo) &&
              coincideCategoria &&
              coincideStock;
        }).toList();

        if (lista.isEmpty) {
          return _MensajeEstado(
            icono: Icons.inventory_2_outlined,
            texto: _hayFiltros || _textoBusqueda.isNotEmpty
                ? 'No hay ingredientes con los filtros seleccionados.'
                : 'No se encontraron ingredientes.\n'
                    'Regístralos desde el módulo de Ingredientes.',
          );
        }

        return Column(
          children: lista
              .map(
                (materia) => _TarjetaIngrediente(
                  materia: materia,
                  onTap: () => _abrirAjusteIngrediente(materia),
                  puedeAjustar:
                      Permisos.instance.puedeAjustarStock(materia.sucursal),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _abrirDetalle(Producto producto) async {
    // El vendedor solo ajusta su sucursal
    if (!Permisos.instance.puedeAjustarStock(producto.sucursal)) {
      avisarSinPermiso(
        context,
        'Solo puedes ajustar el stock de tu sucursal.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AjustarInventarioScreen(
          producto: producto,
          stockService: _stockService,
        ),
      ),
    );
  }

  Future<void> _cambioRapido(Producto producto, int delta) async {
    if (!Permisos.instance.puedeAjustarStock(producto.sucursal)) {
      avisarSinPermiso(
        context,
        'Solo puedes ajustar el stock de tu sucursal.',
      );
      return;
    }
    if (producto.stock + delta < 0) return;

    // Si ya hay un ajuste en curso, ignora el toque
    final id = producto.id;
    if (_ajustando.contains(id)) return;
    setState(() => _ajustando.add(id));
    try {
      await _stockService.ajustarInventario(
        producto: producto,
        tipoAjuste: delta > 0 ? 'Entrada' : 'Salida',
        cantidad: delta.abs(),
        motivo: 'Ajuste rápido desde el listado',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el stock: $e')),
      );
    } finally {
      // Libera el botón
      if (mounted) setState(() => _ajustando.remove(id));
    }
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.stock),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Inventario',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text(
                'Gestión de inventario',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 4),
              Text(
                _seccion == 'Productos'
                    ? 'Ajusta el stock y revisa el estado de cada producto'
                    : 'Ajusta el stock y revisa los ingredientes de cada sucursal',
                style: TextStyle(fontSize: 13, color: _textoClaro),
              ),
              const SizedBox(height: 16),

              // Productos o ingredientes
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _fondoInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _colorBorde),
                ),
                child: Row(
                  children: ['Productos', 'Ingredientes'].map((seccion) {
                    final seleccionada = _seccion == seccion;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _seccion = seccion;
                          _textoBusqueda = '';
                          _buscadorController.clear();
                          _filtroSucursal = '';
                          _filtroEstado = '';
                          _filtroCategoria = '';
                          _filtroStock = '';
                        }),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: seleccionada ? _colorAcento : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            seccion,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: seleccionada ? Colors.white : _textoOscuro,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Buscador
              TextField(
                controller: _buscadorController,
                onChanged: (valor) => setState(() => _textoBusqueda = valor),
                decoration: InputDecoration(
                  hintText: _seccion == 'Productos'
                      ? 'Buscar producto...'
                      : 'Buscar ingrediente...',
                  hintStyle: TextStyle(color: Apariencia.instance.hint, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: _textoClaro),
                  filled: true,
                  fillColor: _fondoInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _colorBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _colorAcento),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Filtros desplegables
              _barraFiltros(),
              const SizedBox(height: 18),

              // Lista en vivo
              if (_seccion == 'Ingredientes')
                _listaIngredientes()
              else
              StreamBuilder<List<Producto>>(
                stream: _productosStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MensajeEstado(
                      icono: Icons.error_outline,
                      texto: 'Error al leer productos: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _colorAcento)),
                    );
                  }

                  final productos = _filtrar(snapshot.data!);
                  if (productos.isEmpty) {
                    return _MensajeEstado(
                      icono: Icons.inventory_2_outlined,
                      texto: _hayFiltros || _textoBusqueda.isNotEmpty
                          ? 'No hay productos con los filtros seleccionados.'
                          : 'No se encontraron productos.\n'
                              'Carga datos de prueba o crea productos desde el módulo de Productos.',
                    );
                  }

                  return Column(
                    children: productos
                        .map(
                          (producto) => _TarjetaProducto(
                            producto: producto,
                            onTap: () => _abrirDetalle(producto),
                            onCambiarStock: (delta) => _cambioRapido(producto, delta),
                            ocupado: _ajustando.contains(producto.id),
                            puedeAjustar: Permisos.instance
                                .puedeAjustarStock(producto.sucursal),
                          ),
                        )
                        .toList(),
                  );
                },
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
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: _textoClaro)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final ValueChanged<int> onCambiarStock;

  // Si es false, se ocultan + y -
  final bool puedeAjustar;

  // True mientras se guarda un ajuste
  final bool ocupado;

  const _TarjetaProducto({
    required this.producto,
    required this.onTap,
    required this.onCambiarStock,
    this.puedeAjustar = true,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    final bajo = producto.bajoStock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _colorBorde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            producto.nombre,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Etiqueta(
                          texto: bajo ? 'BAJO' : 'STOCK OK',
                          color: bajo ? const Color(0xFFEFA93B) : const Color(0xFF5FA45E),
                          icono: bajo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${producto.categoria} · ${producto.sucursal} · C\$${producto.precio.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: _textoClaro),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (puedeAjustar)
                    _BotonRedondo(
                      icono: Icons.remove,
                      onTap: ocupado ? null : () => onCambiarStock(-1),
                    ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${producto.stock}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                  ),
                  if (puedeAjustar)
                    _BotonRedondo(
                      icono: Icons.add,
                      onTap: ocupado ? null : () => onCambiarStock(1),
                      relleno: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData icono;

  const _Etiqueta({required this.texto, required this.color, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 3),
          Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final bool relleno;

  const _BotonRedondo({required this.icono, required this.onTap, this.relleno = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // Se ve apagado cuando está desactivado
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: relleno ? _colorAcento : _fondoInput,
            border: Border.all(color: _colorBorde),
          ),
          child: Icon(icono, size: 16, color: relleno ? Colors.white : _textoOscuro),
        ),
      ),
    );
  }
}

// Ajustar inventario

class AjustarInventarioScreen extends StatefulWidget {
  final Producto producto;
  final StockService stockService;

  const AjustarInventarioScreen({
    super.key,
    required this.producto,
    required this.stockService,
  });

  @override
  State<AjustarInventarioScreen> createState() => _AjustarInventarioScreenState();
}

class _AjustarInventarioScreenState extends State<AjustarInventarioScreen> {
  String _tipoAjuste = 'Entrada';
  final TextEditingController _cantidadController = TextEditingController(text: '0');
  final TextEditingController _motivoController = TextEditingController();
  bool _guardando = false;
  // Una Entrada suele ser producción: descuenta ingredientes (se puede apagar)
  bool _descontarIngredientes = true;

  int get _cantidad => int.tryParse(_cantidadController.text) ?? 0;

  // Solo las Entradas de productos con receta pueden descontar ingredientes
  bool get _puedeDescontar =>
      _tipoAjuste == 'Entrada' && widget.producto.ingredientes.isNotEmpty;

  bool get _descuentaIngredientes => _puedeDescontar && _descontarIngredientes;

  int get _nuevoStock {
    if (_tipoAjuste == 'Entrada') return widget.producto.stock + _cantidad;
    return widget.producto.stock - _cantidad;
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad mayor a 0.')),
      );
      return;
    }
    if (_guardando) return; // ignora toques repetidos
    setState(() => _guardando = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final res = await widget.stockService.ajustarInventario(
        producto: widget.producto,
        tipoAjuste: _tipoAjuste,
        cantidad: _cantidad,
        motivo: _motivoController.text.trim(),
        descontarIngredientes: _descuentaIngredientes,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (res.consumos.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Stock actualizado. Ingredientes descontados: '
              '${res.consumos.map((c) => c.resumen).join(', ')}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el ajuste: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
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
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: Text('Stock', style: TextStyle(color: _textoOscuro)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.producto.nombre,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 2),
              Text(
                'Código: ${widget.producto.codigo} · ${widget.producto.categoria} · ${widget.producto.sucursal}',
                style: TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const SizedBox(height: 18),

              Text('Stock actual', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 4),
              Text(
                '${widget.producto.stock} unidades',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 22),

              Text(
                'Ajustar inventario',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 14),

              Text('Tipo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _tipoAjuste,
                items: const [
                  DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
                  DropdownMenuItem(value: 'Salida', child: Text('Salida')),
                ],
                onChanged: (valor) => setState(() => _tipoAjuste = valor ?? 'Entrada'),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              Text('Cantidad', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              Text('Motivo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                decoration: _decoracionCampo(hint: 'Ej. Producción'),
              ),
              if (_puedeDescontar) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _descontarIngredientes,
                  onChanged: (v) => setState(() => _descontarIngredientes = v),
                  title: Text(
                    'Descontar ingredientes de la receta',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textoOscuro),
                  ),
                  subtitle: Text(
                    'Actívalo si es producción. Desactívalo si es una devolución o una corrección.',
                    style: TextStyle(fontSize: 11, color: _textoClaro),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Vista previa del nuevo stock
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Apariencia.instance.indicador,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('Nuevo Stock', style: TextStyle(fontSize: 12, color: _textoClaro)),
                    const SizedBox(height: 2),
                    Text(
                      '$_nuevoStock unidades',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textoOscuro),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('GUARDAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fondoInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _colorBorde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _colorAcento),
      ),
    );
  }
}


// Tarjeta de un ingrediente en el inventario
class _TarjetaIngrediente extends StatelessWidget {
  final MateriaPrima materia;
  final VoidCallback onTap;

  // Si es false, no se muestra "Ajustar"
  final bool puedeAjustar;

  const _TarjetaIngrediente({
    required this.materia,
    required this.onTap,
    this.puedeAjustar = true,
  });

  @override
  Widget build(BuildContext context) {
    final activo = materia.activo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _colorBorde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            materia.nombre,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Etiqueta(
                          texto: activo ? 'ACTIVO' : 'INACTIVO',
                          color: activo ? const Color(0xFF5FA45E) : const Color(0xFF8A8A8A),
                          icono: activo ? Icons.check_circle_outline : Icons.block,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${materia.categoria} · ${materia.sucursal} · ${materia.codigo}',
                      style: TextStyle(fontSize: 12, color: _textoClaro),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    materia.cantidadConUnidad,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textoOscuro),
                  ),
                  if (puedeAjustar)
                    Text(
                      'Ajustar',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _colorAcento),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ajustar inventario de un ingrediente

class AjustarIngredienteScreen extends StatefulWidget {
  final MateriaPrima materia;
  final StockService stockService;

  const AjustarIngredienteScreen({
    super.key,
    required this.materia,
    required this.stockService,
  });

  @override
  State<AjustarIngredienteScreen> createState() => _AjustarIngredienteScreenState();
}

class _AjustarIngredienteScreenState extends State<AjustarIngredienteScreen> {
  String _tipoAjuste = 'Entrada';
  late String _unidad = widget.materia.unidadMedida;
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  bool _guardando = false;

  double get _cantidad =>
      double.tryParse(_cantidadController.text.trim().replaceAll(',', '.')) ?? 0;

  // Cantidad escrita, pasada a la unidad en que está guardado el stock
  double get _enUnidadDelStock =>
      convertirUnidad(_cantidad, _unidad, widget.materia.unidadMedida) ?? 0;

  double get _nuevoStock {
    final actual = widget.materia.cantidad;
    return redondearCantidad(
      _tipoAjuste == 'Entrada' ? actual + _enUnidadDelStock : actual - _enUnidadDelStock,
    );
  }

  bool get _insuficiente => _nuevoStock < 0;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) {
      _aviso('Ingresa una cantidad mayor a 0.');
      return;
    }
    if (_insuficiente) {
      _aviso('No puedes sacar más de lo que hay en stock.');
      return;
    }
    if (_guardando) return; // ignora toques repetidos
    setState(() => _guardando = true);
    try {
      await widget.stockService.ajustarIngrediente(
        materia: widget.materia,
        tipoAjuste: _tipoAjuste,
        cantidad: _cantidad,
        unidad: _unidad,
        motivo: _motivoController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      final texto = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      _aviso('No se pudo guardar el ajuste: $texto');
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.materia;
    final unidadStock = m.unidadMedida.toLowerCase();
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
                label: Text('Stock', style: TextStyle(color: _textoOscuro)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m.nombre,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 2),
              Text(
                'Código: ${m.codigo} · ${m.categoria} · ${m.sucursal}',
                style: TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const SizedBox(height: 18),

              Text('Stock actual', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 4),
              Text(
                m.cantidadConUnidad,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 22),

              Text(
                'Ajustar inventario',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 14),

              Text('Tipo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _tipoAjuste,
                items: const [
                  DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
                  DropdownMenuItem(value: 'Salida', child: Text('Salida')),
                ],
                onChanged: (valor) => setState(() => _tipoAjuste = valor ?? 'Entrada'),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              Text('Cantidad', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidadController,
                      // Solo números (con un separador decimal)
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (anterior, nuevo) =>
                              RegExp(r'^\d*[.,]?\d*$').hasMatch(nuevo.text)
                                  ? nuevo
                                  : anterior,
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: _decoracionCampo(hint: 'Ej. 250'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Unidades del mismo tipo que el ingrediente (lt -> lt, ml)
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidad,
                      isExpanded: true,
                      items: unidadesCompatibles(m.unidadMedida)
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (valor) =>
                          setState(() => _unidad = valor ?? m.unidadMedida),
                      decoration: _decoracionCampo(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('Motivo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                decoration: _decoracionCampo(hint: 'Ej. Compra de insumos'),
              ),
              const SizedBox(height: 20),

              // Vista previa del nuevo stock
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Apariencia.instance.indicador,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('Nuevo Stock', style: TextStyle(fontSize: 12, color: _textoClaro)),
                    const SizedBox(height: 2),
                    Text(
                      _insuficiente
                          ? 'No alcanza el stock'
                          : '${formatearCantidad(_nuevoStock)} $unidadStock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _insuficiente ? const Color(0xFFB3261E) : _textoOscuro,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('GUARDAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fondoInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _colorBorde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _colorAcento),
      ),
    );
  }
}
